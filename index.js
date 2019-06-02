const child_process = require('child_process');
const path = require('path');
const readline = require('readline');
const shm = require('nodeshm');
const mmap = require('mmap.js');
const fs = require('fs');
const EventEmitter = require('events');

const MAX_WIDTH = 2048;
const MAX_FILENAME = 24; // srsly osx
const MAX_SIZE = MAX_WIDTH * MAX_WIDTH * 4;

function filenameForServer(server) {
    const parts = server.uuid.split('.');
    const last = parts[parts.length - 1];
    const uuid = last.split('-').join('').slice(-MAX_FILENAME);
    return uuid;
}

class SyphonClient {
    constructor(registry, server, frameCallback) {
        this.pending = true;
        this.server = server;
        this.registry = registry;


        const filename = filenameForServer(server);
        shm.shm_unlink(filename);
        this.fd = shm.shm_open(filename, shm.O_CREAT | shm.O_RDWR | shm.O_EXCL, 0o600);
        fs.ftruncateSync(this.fd, MAX_SIZE);
        this.shmBuf = mmap.alloc(
            MAX_SIZE,
            mmap.PROT_READ | mmap.PROT_WRITE,
            mmap.MAP_SHARED,
            this.fd,
            0,
        );

        this.copyBufs = [
            Buffer.alloc(MAX_SIZE),
            Buffer.alloc(MAX_SIZE),
        ];
        this.curBuf = 0;
        this.frameCallback = frameCallback;
        this.promise = new Promise((resolve, reject) => {
            this.onConnected = () => resolve(this);

            registry.send('createClient', {
                uuid: server.uuid,
            });
        });
    }

    cleanup() {
        if (this.pending) {
            const filename = filenameForServer(this.server);
            shm.shm_unlink(filename);
            this.pending = false;
        }
    }

    onFrame(width, height) {
        const buf = this.copyBufs[this.curBuf];
        this.curBuf = 1 - this.curBuf;
        const size = 4 * width * height;
        this.shmBuf.copy(buf);
        this.frameCallback(buf, width, height);
    }
}

class SyphonRegistry extends EventEmitter {
    constructor() {
        super();
        this.serversById = new Map();
        this.clientsByServerId = new Map();
        this.onExit = this.cleanup.bind(this);
    }

    start() {
        process.on('exit', this.onExit);
        process.on('SIGINT', this.onExit);
        process.on('SIGTERM', this.onExit);
        const syphonBufferPath = path.resolve(__dirname, 'native/bin/SyphonBuffer');
        this.ipc = child_process.spawn(syphonBufferPath);
        this.interface = readline.createInterface({
            input: this.ipc.stdout,
        });
        this.interface.on('line', this._onLine.bind(this));
        this.ipc.stderr.on('data', data => console.error(data.toString()));
    }

    onUpdateServers(servers) {
        this.serversById = new Map(servers.map(server => [server.uuid, server]));
        this.emit('servers-updated');
    }

    createClientForServerAsync(server, frameCallback) {
        const client = new SyphonClient(this, server, frameCallback);
        this.clientsByServerId.set(server.uuid, client);
        return client.promise;
    }

    onClientCreated(server) {
        const client = this.clientsByServerId.get(server.uuid);

        if (!client) {
            return;
        }

        client.cleanup();

        client.onConnected();
    }

    onFrame({server, width, height}) {
        const client = this.clientsByServerId.get(server.uuid);

        if (!client) {
            return;
        }

        client.onFrame(width, height);
    }

    _onLine(line) {
        const {command, data} = JSON.parse(line);

        switch (command) {
            case 'updateServers':
                this.onUpdateServers(data);
                break;
            case 'clientCreated':
                this.onClientCreated(data);
                break;
            case 'frame':
                this.onFrame(data);
                break;
            default:
                this.onUnknownCommand(command, data);
        }
    }

    send(command, data) {
        const output = JSON.stringify({command, data}) + '\n';
        this.ipc.stdin.write(output);
    }

    cleanup() {
        for (const client of this.clientsByServerId.values()) {
            client.cleanup();
        }
    }

}

module.exports = {
    SyphonClient,
    SyphonRegistry,
};
