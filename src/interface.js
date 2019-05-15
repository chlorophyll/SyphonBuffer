const child_process = require('child_process');
const readline = require('readline');

const ipc = child_process.spawn('./SyphonBuffer');

const interface = readline.createInterface({
    input: ipc.stdout,
    output: ipc.stdin,
});

interface.on('line', line => {
    console.log(JSON.parse(line));
});

