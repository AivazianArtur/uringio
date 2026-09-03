import asyncio
import sys
sys.path.insert(0, '')
import uringio
from _common import simple_file_example


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

if __name__ == '__main__':
    asyncio.run(execution_context(), loop_factory=uringio.UringioLoop)
