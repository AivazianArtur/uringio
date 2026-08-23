# Architecture info

## Development principles
  - Strong layers between Python interface and C-functionality
  - Trying to stick to Domain Driven Development

**🟢 If you dont know what io_uring is about, what are Fixed and Provided buffers, multishot stream strategy - read explanation [here](IO_URING.md) first**

## Introduction
### io_uring
`uringio` is written natively as C extension for CPython and brings the new event loop, based on `liburing` library - main lib to use `io_uring`.
`io_uring` is an alternate for `epoll` and other `reactor`-based systems.

## Domains
1. Ring
2. Event loop
3. Reader
4. Registry
5. Ops
6. Buffer
7. ExecutionContext
8. Timer
9. Signals

Main challenge to bring `io_uring` in Python was to connect Python event loop and io_uring.

1. From `io_uring` side main thing is `ring` itself. Ring contains two rings actually - `Submission Queue` with `SQE`(`E` is for `event`) and `Completion Queue` with `CQE`. It is really important to understand this concepts, but it all really gives us only one domain - `ring`. There is plan to bring interface to set some ring parametres in next version.

2. From Python side there is main object too - `Event Loop`. Loop is complicated, and its complicity is shown in code: by `loop` domain with `UringioLoop` object and by `reader` domain.

3. `Reader` is part of the loop that reads result of I/O multiplexing mechanism(the output part). In our case(`io_uring`) it reads directly result of operations, but when you work with `epoll` it reads signal about socket readiness.

4. `Registry` is a storage of reference to operations memory and operations metadata, that keep objects alive until they would be mapped with `CQE`s inside `Reader`.

5. Next domain is `Ops`, which contains `File` and `Socket` objects. This domain is mirrorly presented in both c-layer and python-layer. Its purpose is to be an API of system operations.

6. To read and write from/to `Files` and `Sokets`, we need buffers. And there is separate `Buffer` domain for this purpose. Users can use operations with their own buffers or rely on `uringio` functionality of buffer creation. To separate this domain in code there is `BufferPayload` struct.

7. But also `io_uring` gives us some workarounds for buffers and operation handling. There is three categories: `Buffer Mode`, `TransferMode` and `StreamStrategy`. While `BufferMode` is an established in `io_uring` and `liburing` definition, `TransferMode` and `StreamStrategy` are not so, but in some places in internet they are used like that. \
    To use this optimization in `uringio`, we are just initializing this modes inside context manager. For each of mode there is dedicated context manager, but also one more context manager to set them all at once - `ExecutionContext`, and this is the name of this domain. So:
   1. `Buffer Modes`. Different types of optimizations around buffers, mainly around buffer ownership. Without optimizations, user is sending buffers with every syscall.
      1. `Fixed` - On initial stage user is giving his buffers, or relies on `uringio`. Then, for every operation `io_uring` using this fixed buffers. Its on `uringio` side to handle buffer indexes(`FixedBufferIdxRegistry`).
      2. `Provided` - On initial stage its the same as for `Fixed`, but `io_uring` handles even buffer indexes.
      3. `Buffer Ring` - Modern optimization of `Provided` mode. Note, `io_uring` provides functionality to push or pop buffers from ring on the run, but support of this feature would be realized in future `uringio` versions.
   2. `Transfer Mode`. At now there is only one optimization, but we need to create category for it(also in next version there would one more category):
      1. `Zero Copy` - Zero copy is concept for ops to reduce CPU load. This is `io_uring` implementation of this concept.
   3. `Stream Strategy` - Same thing with motivation for existence of this category, and there is only one optimization:
      1. `Multishot` - Allows one `Submission Queue Entry` to generate multiple `Completion Queue Event`s. It is poorly supported and debugged feature for now, so be careful. (v0.4.4)

8. `Timer` - as we are waiting for kernel to complete the operation, we can set timeouts. That and performing separate async timer operation are purpose of this layer.

9. `Signals` - to process cancellation commands, like ctrl-z.

### Structure

Structure of this project is trying to be simple - we have pure c-layer and pure python-layer and layer in between.

- C-layer - Functionality written entirely in C and basically wrappers aroung liburing API
- Python-layer - By analogy it is layer, written with usage of CPython API and CPython objects.
- Layer in between - for now here is really only one thing - registry. It is container to hold objects in between. I wish i could say that in between C-layer and Python-layer, but the meaning is not so. We are working with async nature and giving control of the operations to kernel, so we can do our things. To map the result of kernel with what was intended we need some sort of storage - this is registry.

**More project structure explanation. If you're not interested in contributing, you can [jump to next section](#python-objects)**

#### `Ring`

Code is inside `/src/ring` folder, where you can find:

- ring.c - contains initializer and destroyer of ring; and part of ring initialization separated into its own method.
- sqe_helper.c - contains little wrapper for general SQE creation.

All methods inside `ring.c` are only part of the `loop` initialization and destruction process.

`SQE helper` is spread across C-layer objects only.

> Lays entirely in C-layer.

#### `Loop`

Code is inside `src/python_api/loop`, where you can find:

- loop.h - Defines `UringioLoop` object.
- loop.c - API for `UringioLoop` and redefinitions of `BaseEventLoop` methods.
- shutdown.c - Contains methods for shutting down the `UringioLoop`.
- helpers.c - Contains specific helpers for redefinitions of `BaseEventLoop` methods.
- future.c - Contains little wrapper for future creation. In next versions there will be `FuturePool`.

> Initialization of most objects is happening inside `UringioLoop` construction and initialization, so desctruction too.
> Lays entirely in Python-layer.

#### `Reader`

Code is inside `src/python_api/reader`, where is only:

- on_ready.h - Handler of `Completion Queue` - serializing `CQE` results and setting asyncio feature result by mapping them via `registry`.

> Lays entirely in Python-layer.

#### `Registry`

Code is inside `src/registry`, where you can see:

- registry.h - Defines `RequestRegistry` and `RequestSlot` objects, that are spread around whole project, but mainly is Python API functions. They are internal objects, and its important to know what is inside these objects.
- registry.c - Internal API for registry, works in O(1) Time complexity.

> The only domain intended to be in between c and python layers.

#### `OPS`

Code is inside `src/ops/` AND `src/python_api/ops`. There you can see `Socket` subdomain and `File` subdomain.

- `Socket`:
    - src/ops/sockets/ 
        - sockets.c - C API handlers for socket OPS
        - fixed.c - C API handlers for socket OPS in Fixed buffer mode
        - buffer_select.c - C API handlers for socket OPS in Provided and Buffer Ring buffer modes
        - multishot.c - C API handlers for socket multishot OPS.
        - zerocopy.c - C API handlers for socket zerocopy OPS.
    - src/python_api/ops/sockets/
        - sockets.h - Defines `Socket` object as `UringioSocket` struct.
        - sockets.c - Public API handler for all socket operations.
        - socket_ops_dispatcher.c - Helper functions to dispatch between same socket operations in different execution context.
        - _helpers.c - Some utility helpers, mostly validators.
- `File`:
     - src/ops/files/
         - files.c - C API handler for file OPS
         - fixed.c - C API handler for file OPS in Fixed buffer mode
         - buffer_select.c - C API handler for file OPS in Provided and Buffer Ring modes
         - zerocopy.c - C API handler for file zerocopy OPS
    - src/python_api/ops/files/
         - files.h - Defines `File` object as `UringioFile` struct.
         - enums.c - Defines `ResolveFlags`, `StatxFlags` and `StatxMask` Enums for `open` operation and for now not implemented `statx` operation.
         - files.c - Public API handler for all file operations
         - files_ops_dispatcher.c - Helper functions to dispatch between same file operations in different execution context
         - _helpers.c - Intended for some utility functions, for now there is only one for raising chain of exceptions

 > This domain is mirrored in both c-layer and python-layer

#### `Buffer`

Code is inside `src/python_api/buffers/` and `src/buffer_controllers/`, where we can see:

- src/python_api/buffers/
    - buffers.h - No external objects to use from Python is here, but there is one important internal object, wrapper of buffers - `BufferPayload`.
    - buffers.c - Internal functions for different to wrap buffers in `BufferPayload` object. Some buffers are user inputs, other created by system. Buffer can be `linear` or `vectored`(iovecs), but `BufferPayload` *can* store both.
- src/buffer_controllers/
    - buffer_controllers.h - Define IndexRegistry object for Fixed buffer mode - `FixedBufferIdxRegistry`.
    - buffer_index.c - Internal API for `FixedBufferIdxRegistry`, works in O(1) Time complexity and built same way as main `Registry`.
    - buffer_modes.c - There is `io_uring` concept - `BufferMode`. This is handler to create and destroy all types of `BufferMode`.

> This domain is in both c-layer and python-layer, but not mirrored between themselves.

#### `ExecutionContext`

Code is inside `src/python/api/execution_context/`

- execution_context.h - Provides important internal struct `ExecutionContext` and defines 4 Python object to operate inside context manager - `BufferModeCtx`, `StreamStrategyCtx`, `TransferModeCtx`, `ExecutionContextCtx`. All 4 are running execution context or only one dimension of execution context.
- execution_context.c - Public API of context managers - `BufferModeCtx`, `StreamStrategyCtx`, `TransferModeCtx`, `ExecutionContextCtx`.
- contextvar.c - To run execution context there is solution to use Python's `ContextVar`. Here lays controller of special `ContextVar` for `ExecutionContext`.
- enums.c - Defines `ExecutionContext` specific Python Enums: `BUFFER_MODE`, `STREAM_STRATEGY`, `TRANSFER_MODE` and `PAYLOAD_TYPE`.
- execution_context_enums.c - Internal C Enums, separated in module to get rid of circular dependency.

> Lays entirely in Python-layer.

#### `Timer`

Code is inside `src/timer` and `src/python_api/timer`, where we can see:

- src/timer/
  - timer.c - C handler for timer operation and for timeout operation marking.
- src/python_api/timer/
  - timer.c - Public API handler for timer operation.
  - _helpers.c - Input validators for timer operation and timeout parameters.

> This domain is partly mirrored in both c-layer and python-layer

#### `Signals`

Code is inside `src/python_api/signals` and `src/signals`, where we can see everything related. There is space to separate on CPython-layer and C-layer

## Python objects
- Main:
    - UringioLoop - Main object of library, by the way, users would not interact a lot with it. With initialization of loop there is initialization of all io_uring objects. Child of `BaseEventLoop` object with redefinition of loop's reader. For now custom reader is not really supporting every async operation through `io_uring` rings.
    - File, internally is `UringioFile`. There is its own methods for every file operation in `io_uring`, so this object just use them and is compitable with `UringioLoop`. Every operation is supported in `uringio`, and `io_uring` specific operations, like `read` with `BUFFER_SELECT` `Buffer Mode`.
    - Socket, internally is `UringioSocket`. There are its own methods for every socket operation in `io_uring`, so this object just use them and is compitable with `UringioLoop`. Almost every(for now) operation is supported in `uringio`, and `io_uring` specific operations, like `accept` with `MULTISHOT` `StreamStrategy`.
- Helpers:
    - BufferModeCtx - Special object to implement Pythons context manager of `BufferMode`
    - StreamStrategyCtx - Special object to implement Pythons context manager of `StreamStrategy`
    - TransferModeCtx - Special object to implement Pythons context manager of `TransferMode`
    - ExecutionContextCtx - Special object to implement special context manager, that includes inside itself previous 3.
- Enums:
    - BUFFER_MODE - Enumeration of all possible `buffer mode`s variations, including `NORMAL` mode.
    - STREAM_STRATEGY - Enumeration of all possible `stream strategy`s variations, including `NORMAL` mode.
    - TRANSFER_MODE - Enumeration of all possible `transfer mode`s variations, including `NORMAL` mode.
    - PAYLOAD_TYPE - Enumeration of buffer types - could be `LINEAR`, `IOVECS` or both. Users mainly don't need this, as it detect automatically. But in some cases it could be useful.
    - Resolve Flags - Is using for `File.open()` method only.
    - Statx Flags - Flags for staticx operation. I tried to implement statx operation but faced some troubles, and in favour of time decided to delete method and implement it later, but to leave this enums for it.
    - StatxMask - Flags for statx operation. I tried to implement statx operation but faced some troubles, and in favour of time decided to delete method and implement it later, but to leave this enums for it.
