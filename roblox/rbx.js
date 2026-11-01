// Мини-клиент MCP для Roblox Studio: node rbx.js list | node rbx.js call <tool> '<json args>' | node rbx.js callfile <tool> <file.json>
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const exe = path.join(process.env.LOCALAPPDATA, 'Packages', 'OpenAI.Codex_2p2nqsd0c76g0', 'LocalCache', 'Local', 'Roblox', 'Versions', 'version-7062aec9dbe74b14', 'StudioMCP.exe');
const p = spawn(exe, [], { stdio: ['pipe', 'pipe', 'pipe'] });
let buf = '', id = 0; const waiters = {};
p.stdout.on('data', d => { buf += d.toString('utf8'); let i; while ((i = buf.indexOf('\n')) >= 0) { const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1); if (!line) continue; try { const m = JSON.parse(line); if (m.id !== undefined && waiters[m.id]) { waiters[m.id](m); delete waiters[m.id]; } } catch (e) {} } });
p.stderr.on('data', d => process.stderr.write(d));
function req(method, params) { return new Promise(res => { const i = ++id; waiters[i] = res; p.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: i, method, params }) + '\n'); }); }
(async () => {
  const to = setTimeout(() => { console.log('TIMEOUT'); p.kill(); process.exit(1); }, 120000);
  await req('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'claude-rbx', version: '1' } });
  p.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');
  const [cmd, tool, arg] = process.argv.slice(2);
  if (cmd === 'list') { const r = await req('tools/list', {}); for (const t of r.result.tools) console.log('## ' + t.name + '\n' + (t.description || '').slice(0, 400) + '\n' + JSON.stringify(t.inputSchema).slice(0, 600) + '\n'); }
  else if (cmd === 'call' || cmd === 'callfile') { const args = cmd === 'call' ? JSON.parse(arg || '{}') : JSON.parse(fs.readFileSync(arg, 'utf8')); const r = await req('tools/call', { name: tool, arguments: args }); console.log(JSON.stringify(r.result || r.error, null, 1).slice(0, 20000)); }
  clearTimeout(to); p.kill(); process.exit(0);
})();
