import socketserver
import threading


class TCPHandler(socketserver.BaseRequestHandler):
    def handle(self):
        while data := self.request.recv(65536):
            self.request.sendall(data)


class UDPHandler(socketserver.BaseRequestHandler):
    def handle(self):
        data, socket = self.request
        socket.sendto(data, self.client_address)


if __name__ == '__main__':
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    tcp = socketserver.ThreadingTCPServer(('127.0.0.1', 18780), TCPHandler)
    udp = socketserver.ThreadingUDPServer(('127.0.0.1', 18780), UDPHandler)
    threading.Thread(target=udp.serve_forever, daemon=True).start()
    try:
        tcp.serve_forever()
    finally:
        tcp.server_close()
        udp.shutdown()
        udp.server_close()
