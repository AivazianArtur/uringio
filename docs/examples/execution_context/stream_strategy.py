import asyncio
import sys
sys.path.insert(0, '')
import uringio
from _common import simple_socket_example

async def stream_strategy():
    loop = asyncio.get_running_loop()
    with loop.stream_strategy(stream=uringio.STREAM_STRATEGY.ONESHOT):
        await simple_socket_example()


if __name__ == '__main__':
    asyncio.run(stream_strategy(), loop_factory=uringio.UringioLoop)
