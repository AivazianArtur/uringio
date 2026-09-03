import asyncio
import sys
sys.path.insert(0, '')
import uringio


HOST = '127.0.0.1'
PORT = 12877


async def main():
    async with await uringio.prep_socket() as server_sock:
        print(f'{server_sock = }')
        await server_sock.bind(HOST, PORT)
        await server_sock.listen(1)
        print(f'Server listening on {HOST}:{PORT}')

        async with await uringio.prep_socket() as client_sock:
            await client_sock.connect(HOST, PORT)
            print('Client connected')

            accept_future = server_sock.accept()
            async with await accept_future as server_conn:
                print(f'{server_conn = }')

                message = b'Hello from client!'
                await client_sock.send(message)
                print('Client sent message')

                received_data = await server_conn.recv()
                result = received_data.decode()
                print(f'Server received: {result}')
                assert result == message.decode()

    print('Sockets closed')


asyncio.run(main(), loop_factory=uringio.UringioLoop)
