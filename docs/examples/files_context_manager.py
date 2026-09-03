import os

import asyncio
import sys
sys.path.insert(0, '')
import uringio


TEMPFILE = 'docs/assets/tempfile.txt'


async def main():
    async with await uringio.open_file(path=TEMPFILE) as uring_file:
        print('File opened, fd:', uring_file)

        data = b'Hello, uringio!\n'
        bytes_written = await uring_file.write(data=data)
        print('Bytes written:', bytes_written)

        read_data = await uring_file.read()

        result = read_data.decode()
        print('Read data:', result)
        assert result == data.decode()

    print('File closed')


asyncio.run(main(), loop_factory=uringio.UringioLoop)
os.remove(TEMPFILE)
