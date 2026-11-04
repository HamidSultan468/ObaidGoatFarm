// Minimal SMTP server for testing email delivery locally (no TLS, no auth).
// Every accepted message is appended as one JSON line to <logFile>.
// Recipients matching <rejectPattern> get "550" so retries can be tested.
// Usage: node scripts/e2e/smtp-sink.mjs <port> <logFile> [rejectPattern]
import { appendFileSync } from 'node:fs';
import { createServer } from 'node:net';

const port = Number(process.argv[2] ?? 2525);
const logFile = process.argv[3] ?? 'smtp-sink.jsonl';
const reject = process.argv[4] ? new RegExp(process.argv[4], 'i') : null;

createServer((socket) => {
  let buffer = '';
  let inData = false;
  let message = { from: '', to: [], data: '' };
  const reply = (line) => socket.write(`${line}\r\n`);
  reply('220 smtp-sink ready');

  socket.on('data', (chunk) => {
    buffer += chunk.toString('utf8');
    let index;
    while ((index = buffer.indexOf('\r\n')) !== -1) {
      const line = buffer.slice(0, index);
      buffer = buffer.slice(index + 2);
      if (inData) {
        if (line === '.') {
          inData = false;
          appendFileSync(logFile, JSON.stringify({ ...message, receivedAt: new Date().toISOString() }) + '\n');
          message = { from: '', to: [], data: '' };
          reply('250 OK queued');
        } else {
          message.data += (line.startsWith('..') ? line.slice(1) : line) + '\n';
        }
        continue;
      }
      const command = line.slice(0, 4).toUpperCase();
      if (command === 'EHLO' || command === 'HELO') reply('250 smtp-sink');
      else if (command === 'MAIL') { message.from = line.slice(10).trim(); reply('250 OK'); }
      else if (command === 'RCPT') {
        const to = line.slice(8).trim();
        if (reject && reject.test(to)) reply('550 Mailbox unavailable (test rejection)');
        else { message.to.push(to); reply('250 OK'); }
      }
      else if (command === 'DATA') { inData = true; reply('354 End data with <CR><LF>.<CR><LF>'); }
      else if (command === 'RSET') { message = { from: '', to: [], data: '' }; reply('250 OK'); }
      else if (command === 'NOOP') reply('250 OK');
      else if (command === 'QUIT') { reply('221 Bye'); socket.end(); }
      else reply('502 Command not implemented');
    }
  });
  socket.on('error', () => {});
}).listen(port, '127.0.0.1', () => console.log(`smtp-sink on ${port}, logging to ${logFile}`));
