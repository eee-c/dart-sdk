// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class _SocketInputStream implements SocketInputStream {
  _SocketInputStream(Socket socket) : _socket = socket {
    if (_socket._id == -1) _closed = true;
    _socket.onClosed = _onClosed;
  }

  List<int> read([int len]) {
    int bytesToRead = available();
    if (bytesToRead == 0) return null;
    if (len !== null) {
      if (len <= 0) {
        throw new StreamException("Illegal length $len");
      } else if (bytesToRead > len) {
        bytesToRead = len;
      }
    }
    ByteArray buffer = new ByteArray(bytesToRead);
    int bytesRead = _socket.readList(buffer, 0, bytesToRead);
    if (bytesRead == 0) {
      // On MacOS when reading from a tty Ctrl-D will result in one
      // byte reported as available. Attempting to read it out will
      // result in zero bytes read. When that happens there is no data
      // which is indicated by a null return value.
      return null;
    } else if (bytesRead < bytesToRead) {
      ByteArray newBuffer = new ByteArray(bytesRead);
      newBuffer.setRange(0, bytesRead, buffer);
      return newBuffer;
    } else {
      return buffer;
    }
  }

  int readInto(List<int> buffer, [int offset = 0, int len]) {
    if (_closed) return null;
    if (len === null) len = buffer.length;
    if (offset < 0) throw new StreamException("Illegal offset $offset");
    if (len < 0) throw new StreamException("Illegal length $len");
    return _socket.readList(buffer, offset, len);
  }

  int available() => _socket.available();

  void pipe(OutputStream output, [bool close = true]) {
    _pipe(this, output, close: close);
  }

  void close() {
    if (!_closed) {
      _socket.close();
    }
  }

  bool get closed() => _closed;

  void set onData(void callback()) {
    _socket._onData = callback;
  }

  void set onClosed(void callback()) {
    _clientCloseHandler = callback;
    _socket._onClosed = _onClosed;
  }

  void _onClosed() {
    _closed = true;
    if (_clientCloseHandler !== null) {
      _clientCloseHandler();
    }
  }

  void set onError(void callback(Exception e)) {
    _errorCallback = callback;
  }

  void _onError(Exception e) {
    close();
    if (_errorCallback != null) _errorCallback(e);
  }

  Socket _socket;
  bool _closed = false;
  Function _clientCloseHandler;
  Function _errorCallback;
}


class _SocketOutputStream
    extends _BaseOutputStream implements SocketOutputStream {
  _SocketOutputStream(Socket socket)
      : _socket = socket, _pendingWrites = new _BufferList();

  bool write(List<int> buffer, [bool copyBuffer = true]) {
    return _write(buffer, 0, buffer.length, copyBuffer);
  }

  bool writeFrom(List<int> buffer, [int offset = 0, int len]) {
    return _write(
        buffer, offset, (len == null) ? buffer.length - offset : len, true);
  }

  void close() {
    if (!_pendingWrites.isEmpty()) {
      // Mark the socket for close when all data is written.
      _closing = true;
      _socket._onWrite = _onWrite;
    } else {
      // Close the socket for writing.
      _socket._closeWrite();
      _closed = true;
    }
  }

  void destroy() {
    _socket.onWrite = null;
    _pendingWrites.clear();
    _socket.close();
    _closed = true;
  }

  void set onNoPendingWrites(void callback()) {
    _onNoPendingWrites = callback;
    if (_onNoPendingWrites != null) {
      _socket._onWrite = _onWrite;
    }
  }

  bool _write(List<int> buffer, int offset, int len, bool copyBuffer) {
    if (_closing || _closed) throw new StreamException("Stream closed");
    int bytesWritten = 0;
    if (_pendingWrites.isEmpty()) {
      // If nothing is buffered write as much as possible and buffer
      // the rest.
      bytesWritten = _socket.writeList(buffer, offset, len);
      if (bytesWritten == len) return true;
    }

    // Place remaining data on the pending writes queue.
    int notWrittenOffset = offset + bytesWritten;
    if (copyBuffer) {
      List<int> newBuffer =
          buffer.getRange(notWrittenOffset, len - bytesWritten);
      _pendingWrites.add(newBuffer);
    } else {
      assert(offset + len == buffer.length);
      _pendingWrites.add(buffer, notWrittenOffset);
    }
    _socket._onWrite = _onWrite;
    return false;
  }

  void _onWrite() {
    // Write as much buffered data to the socket as possible.
    while (!_pendingWrites.isEmpty()) {
      List<int> buffer = _pendingWrites.first;
      int offset = _pendingWrites.index;
      int bytesToWrite = buffer.length - offset;
      int bytesWritten = _socket.writeList(buffer, offset, bytesToWrite);
      _pendingWrites.removeBytes(bytesWritten);
      if (bytesWritten < bytesToWrite) {
        _socket._onWrite = _onWrite;
        return;
      }
    }

    // All buffered data was written.
    if (_closing) {
      _socket._closeWrite();
      _closed = true;
    } else {
      if (_onNoPendingWrites != null) _onNoPendingWrites();
    }
    if (_onNoPendingWrites == null) {
      _socket._onWrite = null;
    } else {
      _socket._onWrite = _onWrite;
    }
  }

  void set onError(void callback(Exception e)) {
    _errorCallback = callback;
  }

  void _onError(Exception e) {
    close();
    if (_errorCallback != null) _errorCallback(e);
  }

  Socket _socket;
  _BufferList _pendingWrites;
  var _onNoPendingWrites;
  Function _errorCallback;
  bool _closing = false;
  bool _closed = false;
}
