import asyncio
import sys
sys.path.insert(0, '')
import uringio

from _common import simple_file_example

async def buffer_mode():
    loop = asyncio.get_running_loop()
    buf = bytearray(4096)
    with loop.buffer_mode(mode=uringio.BUFFER_MODE.FIXED, buffers=[buf], payload_type=uringio.PAYLOAD_TYPE.IOVEC):
        await simple_file_example()


if __name__ == '__main__':
    asyncio.run(buffer_mode(), loop_factory=uringio.UringioLoop)
