# User guide

**See more examples in [docs/examples](https://github.com/AivazianArtur/uringio/tree/main/docs/examples)**

### Installation
First off, install library with
```python
pip install uringio
```
### Initialize `UringioLoop`
To start using `uringio` user need to initialize special `io_uring` loop - `UringioLoop`

Its quite simple:
```python
asyncio.run(main(), loop_factory=uringio.UringioLoop)
```

Or with Runner:
```python
with asyncio.Runner(loop_factory=uringio.UringioLoop) as runner:
    runner.run(main())
```

### `File` and `Socket` Operations
#### `File` operations
`uringio.File` object acts as interface to true asynchronous file operations in Python.
**See full [File API](docs/API.md)**

You can import it by
```python
from uringio import File
``` 
Let's create simple example of writing and reading from file:

1. Open file asynchronously
```python
file = await uringio.open_file(path='path/to/file.txt')
``` 
2. Write to file, asynchronously. Better use bytes in v0.4.4
```python
await file.write(data=b'Hello uringio!\n')
```
3. Read from file, again - asynchronously
```python
result_data = await file.read()
```
4. Closing file asynchronously 
```python
await file.close()
```


Now lets put it inside function:
```python
async def file_simple_example():
    file = await uringio.open_file(path='path/to/file.txt')
    await file.write(data=b'Hello, uringio!\n')
    await file.read()
    await file.close()
```

**Important note** - you can await this function only with new `UringioLoop` loop.

See how easy it is actually to combine everything we know so far:
```python
import asyncio
import uringio

async def file_simple_example():
    file = await uringio.open_file(path='path/to/file.txt')
    await file.write(data=b'Hello, uringio!\n')
    await file.read()
    await file.close()

asyncio.run(file_simple_example(), loop_factory=uringio.UringioLoop)
```

But actual code would be even simpler - with usage of file context manager
```python
import asyncio
import uringio

async def file_simple_example():
    async with await uringio.open_file(path='path/to/file.txt') as file:
        await file.write(data=b'Hello, uringio!\n')
        await file.read()

asyncio.run(file_simple_example(), loop_factory=uringio.UringioLoop)
```
You can also use `asyncio.Runner` when you need more control over the event loop:
```python
with asyncio.Runner(loop_factory=uringio.UringioLoop) as runner:
    runner.run(file_simple_example())
```

#### `Socket` operations
`uringio.Socket` object acts as interface to asynchronous socket operations in Python using `io_uring`, not `epoll`.
**See full [Socket API](docs/API.md)**

You can import it by
```python
from uringio import Socket
```

Let's create simple example of sending message from one socket to another:

1. Prepare socket
```python
socket = await uringio.prep_socket()
```
2. Bind to socket
```python
await socket.bind('127.0.0.1', 12878)
```
3. Listen socket
```python
await socket.listen()
```
4. Accept an incoming connection
```python
connection = await socket.accept()
```
5. Receive data from the connection
```python
await connection.recv()
```
6. Send data through a socket
```python
await socket.send(data)
```
7. Close the socket asynchronously
```python
await socket.close()
```

Now let's put everything together into a simple client-server example;

As with file operations, socket operations must be executed using the `UringioLoop`:

```python
import asyncio
import uringio

async def socket_simple_example():
    server_socket = await uringio.prep_socket()
    await server_socket.bind('127.0.0.1', 12878)
    await server_socket.listen()

    client_socket = await uringio.prep_socket()

    await client_socket.connect('127.0.0.1', 12878)

    server_connection = await server_socket.accept()
    await client_socket.send(b'Hello from client!')

    received_data = await server_connection.recv()

    await client_socket.close()
    await server_connection.close()
    await server_socket.close()

asyncio.run(socket_simple_example(), loop_factory=uringio.UringioLoop)
```
The example above creates two sockets: one for the server and one for the client.

The server socket is bound to `127.0.0.1:12878` and starts listening for incoming connections.

The client then connects to the server, after which the server accepts the connection and receives the message sent by the client.

You can also use `asyncio.Runner` when you need more control over the event loop:
```python
with asyncio.Runner(loop_factory=uringio.UringioLoop) as runner:
    runner.run(socket_simple_example())
```

And there is support of context manager protocol:
```python
import asyncio
import uringio

async def socket_simple_example():
    async with await uringio.prep_socket() as server_socket:
        await server_socket.bind('127.0.0.1', 12878)
        await server_socket.listen()

        async with await uringio.prep_socket() as client_socket:
            await client_socket.connect('127.0.0.1', 12878)

            async with await accept_future as server_connection:
                await client_socket.send(b'Hello from client!')
                received_data = await server_connection.recv()

asyncio.run(socket_simple_example(), loop_factory=uringio.UringioLoop)
```

### Execution Context
To use advanced features, use different types of context managers.

**Note that not all operations are supported in every context, but it will automatically dispatched to supported operation**

#### TransferMode
To use operations in zero-copy mode, use `UringioLoop.transfer_mode` context manager, with `uringio.TRANSFER_MODE` Enum:
```python
import asyncio
import uringio

async def transfer_mode():
    loop = asyncio.get_running_loop()
    with loop.transfer_mode(mode=uringio.TRANSFER_MODE.ZERO_COPY):
        await simple_socket_example()

asyncio.run(transfer_mode(), loop_factory=uringio.UringioLoop)
```
There are `NORMAL` and `ZERO_COPY` values in `TRANSFER_MODE` Enum

#### StreamStrategy
To use Multishot operations, use `stream_strategy` context manager, with `uringio.STREAM_STRATEGY` Enum. In v0.4.4 its better to not use it: 
```python
import asyncio
import uringio

async def stream_strategy():
    loop = asyncio.get_running_loop()
    with loop.stream_strategy(stream=uringio.STREAM_STRATEGY.MULTISHOT):
        await simple_socket_example()

asyncio.run(stream_strategy(), loop_factory=uringio.UringioLoop)
```
There are `ONESHOT` and `MULTISHOT` values in `STREAM_STRATEGY` Enum

#### BufferMode
To use operations in zero-copy mode, use `UringioLoop.buffer_mode` context manager with `uringio.BUFFER_MODE` Enum:
##### Fixed buffer mode
> Note, FIXED buffer mode currently working only with files

```python
import asyncio
import uringio

async def buffer_mode():
    loop = asyncio.get_running_loop()
    buf = bytearray(4096)
    with loop.buffer_mode(mode=uringio.BUFFER_MODE.FIXED, buffers=[buf]):
        await simple_file_example()

asyncio.run(buffer_mode(), loop_factory=uringio.UringioLoop)
```

There are `NORMAL`, `FIXED`, `PROVIDED` and `BUF_RING` values in `BUFFER_MODE` Enum

#### ExecutionContext
To set context manager with different types of all regimes above - use `UringioLoop.execution_context` context manager:
```python
import asyncio
import uringio

async def execution_context():
    loop = asyncio.get_running_loop()

    buf = bytearray(4096)
    with loop.execution_context(
        stream_strategy=uringio.STREAM_STRATEGY.MULTISHOT,
        buffer_mode=uringio.BUFFER_MODE.FIXED,
        transfer_mode=uringio.TRANSFER_MODE.ZERO_COPY,
        buffers=[buf],
    ):
        await simple_file_example()

asyncio.run(buffer_mode(), loop_factory=uringio.UringioLoop)
```

If you face some problems, please leave an issue on [Github](https://github.com/AivazianArtur/uringio/issues)
