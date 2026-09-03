## v0.4.5
### Added
- Logo of uringio

## v0.4.4
### Added
- PyPI link in documentation
### Fixed
- Fixed relative paths in `docs/IO_URING.md` for illustrations
- Fixed gawk dependency error of `make build` for new systems
- Fixed name path of `UringioLoop`
- Fixed [CI error](https://github.com/AivazianArtur/uringio/actions/runs/32414196865/job/96571873503)
 
## v0.4.3
### Updated
- Update version inside pyproject and documentation

## v0.4.2
### Fixed
- Documentation and examples fix

## v0.4.1
### Fixed
- Bunch of release and pypi publish fixes

## v0.4.0
### Added
- Implemented new layer - Buffer Layer:
    - Main struct - `BufferPayload`
    - Distinguished Linear and Vectored buffer types
    - Interface for different scenarios of buffer creation
- Support of advanced io_uring features via new layer - `ExecuitionContext`: 
  - Support of fixed buffers, including implementation of registry for fixed buffers
  - Support of provided buffers
  - Partial support of buffer ring
  - Support of zero-copy operations
  - Partial support of multishot operations
  - Special ContextVar to keep `ExecutionContext`
  - Special context managers: `ProvidedBuffers`, `StreamStrategy`, `TransferMode`, `ExecutionContext`
- Support of context manager protocol for `File` and `Socket`
- Initial documentation: architecture.md, developing.md, user_guide.md, contributing.md, io_uring.md
- Initial Python and C tests (AI generated)
- Added benchmarks (AI generated)
- Initial documentation written and build for contributing
- Build via cbuildwheel
- mkdocs generation
- CI: `docs` and `wheels` pipes
### Updated
- Makefile: fixed sanitaizer stage, added new stages
- GitHub CI: partly added tests stage
- Project and its internals renamed from `puring` to `uringio`
### Fixed
- Bunch of memory related bug fixes
### Removed
- GitHub CI: removed sanitizer stage(redundant)

## v0.3.0
### Added
- Raising Python exceptions.
- Handling of system signals.
- Implemented event's timer interface.
- Prepared interface for event timeout.
- Implemented GitHUb CI with linter stages.
### Updated
- `Uring` prefix renamed to `Puring`.
- `PuringLoop` became child of asyncio event-loop.
- `PuringFile` interface completed.
- `PuringSocket` interface completed.
- Makefile includes linter stages.

## v0.2.0
### Added
- Sockets debugged and simple benchmark added.
- Implemented check that calls are made from loop.
- Implemented UringFile to fix file interface and shadow FD usage.
### Updated
- `peek_cqe` replaced with `wait_cqe_timeout` on app shutdown and loop closing.
- Module initialization moved to separate module.
- Separation between C and Python layers imporved.

## v0.1.0
### Added
- First version with basic functionality
