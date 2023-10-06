# VEMINI

Vemini is a really small [gemini](https://geminiprotocol.net/) server written in  [V language](https://github.com/vlang/v)

## Usage

```
./vemini [--root <root CA certs>] [--crt <SSL certificate>] [--key <SSL cert key>] [--validate] [--dir <content directory>] [--host <hostname>] [--port <port>]

```

* --validate validates the SSL certificate (no self signed, etc)

All options have simple defaults if you don't want to pass arguments:
* --root: ./certs/root.ca
* --crt: ./certs/crt.pem
* --key: ./certs/key.pem
* --dir: ./gemini/
* --host: localhost
* --port: 1965 (default gemini port)

## Build and Install

* Requisites: V Language

Clone the repository

```
$ git clone https://github.com/ladecadence/Vemini.git
```

And build it
```
$ cd Vemini
$ v .
```


## License

Vemini is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. See LICENSE.

Vemini is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

