import sys
sys.path.insert(0, '')
import uringio


HOST = '127.0.0.1'
PORT = 12878


async def simple_socket_example():
    server_sock = await uringio.prep_socket()
    print(f'{server_sock = }')
    await server_sock.bind(HOST, PORT)
    await server_sock.listen(1)
    print(f'Server listening on {HOST}:{PORT}')

    client_sock = await uringio.prep_socket()

    await client_sock.connect(HOST, PORT)
    print('Client connected')

    server_conn = await server_sock.accept()
    print(f'{server_conn = }')
    message = b'Hello from client!'
    await client_sock.send(message)
    print(f'Client sent message')

    received_data = await server_conn.recv()

    result = received_data.decode()
    print(f'Server received: {result}')
    assert result == message.decode()

    await client_sock.close()
    await server_conn.close()
    await server_sock.close()
    print('Sockets closed')


TEMPFILE = 'docs/assets/tempfile.txt'
async def simple_file_example():
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
