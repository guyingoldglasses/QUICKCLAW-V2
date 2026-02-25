// ===========================================================================
// QuickClaw Dashboard — server.js v2 (local/external-drive compatible)
// ===========================================================================

const express = require('express');
const { execSync, exec } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

const app = express();
const PORT = process.env.DASHBOARD_PORT || 3000;

const QUICKCLAW_ROOT = process.env.QUICKCLAW_ROOT || path.resolve(__dirname, '..');
const INSTALL_DIR = path.join(QUICKCLAW_ROOT, 'openclaw');
const CONFIG_DIR = path.join(INSTALL_DIR, 'config');
const LOG_DIR = path.join(QUICKCLAW_ROOT, 'logs');
const PID_DIR = path.join(QUICKCLAW_ROOT, '.pids');
const DATA_DIR = path.join(QUICKCLAW_ROOT, 'dashboard-data');
const DASHBOARD_PUBLIC = path.join(__dirname, 'public');

app.use(express.static(DASHBOARD_PUBLIC));
app.use(express.json({ limit: '2mb' }));

for (const d of [LOG_DIR, PID_DIR, DATA_DIR]) {
  if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true });
}

function fileExists(p) { try { return fs.existsSync(p); } catch { return false; } }
function readTextSafe(p, fallback = '') { try { return fs.readFileSync(p, 'utf8'); } catch { return fallback; } }
function writeJson(p, obj) { fs.writeFileSync(p, JSON.stringify(obj, null, 2)); }
function readJson(p, fallback) { try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return fallback; } }
function tailLog(logFile, lines = 80) {
  const p = path.join(LOG_DIR, logFile);
  if (!fileExists(p)) return [];
  try {
    const out = execSync(`tail -${Math.min(lines, 300)} "${p}" 2>/dev/null`, { encoding: 'utf8', timeout: 5000 });
    return out.split('\n').filter(Boolean);
  } catch {
    return [];
  }
}
function readPid(name) {
  const p = path.join(PID_DIR, `${name}.pid`);
  if (!fileExists(p)) return null;
  const pid = parseInt(readTextSafe(p).trim(), 10);
  if (!pid || Number.isNaN(pid)) return null;
  try { process.kill(pid, 0); return pid; } catch { return null; }
}
function checkPort(port) {
  try { execSync(`lsof -i :${port}`, { stdio: 'ignore', timeout: 2000 }); return true; } catch { return false; }
}
function cfgPath() { return path.join(CONFIG_DIR, 'default.yaml'); }
function ensureWithinRoot(rawPath, base = QUICKCLAW_ROOT) {
  const resolved = path.resolve(rawPath);
  const baseResolved = path.resolve(base);
  if (resolved === baseResolved || resolved.startsWith(baseResolved + path.sep)) return resolved;
  throw new Error('Path outside QuickClaw root is not allowed');
}
function gatewayStartCommand(configFlag = '') {
  const localA = path.join(INSTALL_DIR, 'node_modules', '.bin', 'open-claw');
  const localB = path.join(INSTALL_DIR, 'node_modules', '.bin', 'openclaw');
  if (fileExists(localA)) return { cmd: `"${localA}" start ${configFlag}`.trim(), cwd: QUICKCLAW_ROOT };
  if (fileExists(localB)) return { cmd: `"${localB}" start ${configFlag}`.trim(), cwd: QUICKCLAW_ROOT };
  try { execSync('which open-claw', { stdio: 'ignore' }); return { cmd: `open-claw start ${configFlag}`.trim(), cwd: QUICKCLAW_ROOT }; } catch {}
  try { execSync('which openclaw', { stdio: 'ignore' }); return { cmd: `openclaw start ${configFlag}`.trim(), cwd: QUICKCLAW_ROOT }; } catch {}
  return { cmd: `npx open-claw start ${configFlag}`.trim(), cwd: INSTALL_DIR };
}

function profileFile() { return path.join(DATA_DIR, 'profiles.json'); }
function getProfiles() {
  const d = readJson(profileFile(), null);
  if (Array.isArray(d)) return d;
  const starter = [{
    id: 'default', name: 'Default', active: true,
    model: 'default', provider: 'local', notes: 'QuickClaw default profile'
  }];
  writeJson(profileFile(), starter);
  return starter;
}
function saveProfiles(p) { writeJson(profileFile(), p); }

// Core status
app.get('/api/health', (req, res) => {
  const gw = readPid('gateway');
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    dashboard: { running: true, port: PORT, pid: process.pid },
    gateway: { running: !!gw, pid: gw, port: 5000, portListening: checkPort(5000) },
    system: { platform: os.platform(), arch: os.arch(), nodeVersion: process.version }
  });
});

app.get('/api/status', (req, res) => {
  const gw = readPid('gateway');
  res.json({
    gateway: { running: !!gw, pid: gw, portActive: checkPort(5000) },
    dashboard: { running: true, pid: process.pid, port: PORT },
    install: { path: INSTALL_DIR, exists: fileExists(INSTALL_DIR), configExists: fileExists(cfgPath()) }
  });
});

app.get('/api/system', (req, res) => {
  const gw = readPid('gateway');
  const db = readPid('dashboard') || process.pid;
  res.json({
    quickclawRoot: QUICKCLAW_ROOT,
    installDir: INSTALL_DIR,
    gateway: { running: !!gw, pid: gw, port: 5000, up: checkPort(5000) },
    dashboard: { running: true, pid: db, port: PORT },
    logs: { gateway: path.join(LOG_DIR, 'gateway.log'), dashboard: path.join(LOG_DIR, 'dashboard.log') },
    platform: os.platform(),
    externalDriveMode: QUICKCLAW_ROOT.startsWith('/Volumes/')
  });
});

app.get('/api/alerts', (req, res) => {
  const alerts = [];
  if (!fileExists(path.join(INSTALL_DIR, 'node_modules'))) {
    alerts.push({ type: 'warn', icon: '⚠', message: 'OpenClaw package folder not found. Run installer again.' });
  }
  if (!fileExists(cfgPath())) {
    alerts.push({ type: 'warn', icon: '⚠', message: 'Config file missing: openclaw/config/default.yaml' });
  }
  res.json({ alerts });
});

app.get('/api/logs/:service', (req, res) => {
  const svc = req.params.service;
  if (!['gateway', 'dashboard'].includes(svc)) return res.status(400).json({ error: 'Invalid service' });
  res.json({ service: svc, lines: tailLog(`${svc}.log`, parseInt(req.query.lines || '80', 10)) });
});

app.get('/api/config', (req, res) => {
  const p = cfgPath();
  res.json({ exists: fileExists(p), content: readTextSafe(p, null) });
});

app.get('/api/addons', (req, res) => {
  const c = readTextSafe(cfgPath(), '');
  const has = (k) => c.includes(`${k}:`);
  res.json({
    openai: { name: 'OpenAI', status: has('openai') ? 'needs_config' : 'missing' },
    ftp: { name: 'FTP', status: has('ftp') ? 'needs_config' : 'missing' },
    email: { name: 'Email', status: has('email') ? 'needs_config' : 'missing' },
    skills: { name: 'Skills Bundle', status: fileExists(path.join(INSTALL_DIR, 'skills')) ? 'enabled' : 'missing' }
  });
});

app.post('/api/gateway/start', (req, res) => {
  const existing = readPid('gateway');
  if (existing) return res.json({ success: true, message: 'Gateway already running', pid: existing });

  const cPath = cfgPath();
  const configFlag = fileExists(cPath) ? `--config "${cPath}"` : '';
  const logPath = path.join(LOG_DIR, 'gateway.log');
  const { cmd, cwd } = gatewayStartCommand(configFlag);

  try {
    const child = exec(`${cmd} >> "${logPath}" 2>&1`, { cwd });
    if (child.pid) {
      fs.writeFileSync(path.join(PID_DIR, 'gateway.pid'), String(child.pid));
      child.unref();
    }
    res.json({ success: true, message: 'Gateway starting...', pid: child.pid, command: cmd });
  } catch (e) {
    res.json({ success: false, message: `Failed to start gateway: ${e.message}` });
  }
});

app.post('/api/gateway/stop', (req, res) => {
  const pid = readPid('gateway');
  if (!pid) return res.json({ success: false, message: 'Gateway not running' });
  try {
    process.kill(pid, 'SIGTERM');
    const p = path.join(PID_DIR, 'gateway.pid');
    if (fileExists(p)) fs.unlinkSync(p);
    res.json({ success: true, message: 'Gateway stopped', pid });
  } catch (e) {
    res.json({ success: false, message: `Stop failed: ${e.message}` });
  }
});

app.post('/api/dashboard/restart', async (req, res) => {
  const pid = readPid('gateway');
  if (pid) {
    try { process.kill(pid, 'SIGTERM'); } catch {}
    try { fs.unlinkSync(path.join(PID_DIR, 'gateway.pid')); } catch {}
  }
  setTimeout(() => {
    const cPath = cfgPath();
    const configFlag = fileExists(cPath) ? `--config "${cPath}"` : '';
    const logPath = path.join(LOG_DIR, 'gateway.log');
    const { cmd, cwd } = gatewayStartCommand(configFlag);
    const child = exec(`${cmd} >> "${logPath}" 2>&1`, { cwd });
    if (child.pid) {
      fs.writeFileSync(path.join(PID_DIR, 'gateway.pid'), String(child.pid));
      child.unref();
    }
  }, 500);
  res.json({ success: true, message: 'Gateway restart triggered' });
});

// Profiles
app.get(['/api/profiles', '/api/profiles/'], (req, res) => {
  res.json({ profiles: getProfiles() });
});
app.post('/api/profiles', (req, res) => {
  const p = getProfiles();
  const id = `p-${Date.now()}`;
  p.push({ id, name: req.body?.name || `Profile ${p.length + 1}`, active: false, ...req.body });
  saveProfiles(p);
  res.json({ ok: true, id, profiles: p });
});
app.post('/api/profiles/wizard', (req, res) => {
  const body = req.body || {};
  const p = getProfiles();
  const id = `p-${Date.now()}`;
  p.forEach(x => { x.active = false; });
  p.push({ id, name: body.name || 'Wizard Profile', active: true, ...body });
  saveProfiles(p);
  res.json({ ok: true, id, profile: p.find(x => x.id === id) });
});

// File browser / editor
app.get(['/api/system/browse', '/api/system/browse?dir='], (req, res) => {
  const dir = req.query.dir ? ensureWithinRoot(req.query.dir) : QUICKCLAW_ROOT;
  try {
    const items = fs.readdirSync(dir, { withFileTypes: true }).map((d) => ({
      name: d.name,
      path: path.join(dir, d.name),
      type: d.isDirectory() ? 'dir' : 'file'
    }));
    res.json({ dir, items });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});
app.get('/api/system/readfile', (req, res) => {
  try {
    const p = ensureWithinRoot(req.query.path || '');
    res.json({ path: p, content: readTextSafe(p, '') });
  } catch (e) { res.status(400).json({ error: e.message }); }
});
app.put('/api/system/writefile', (req, res) => {
  try {
    const p = ensureWithinRoot(req.body?.path || '');
    fs.writeFileSync(p, req.body?.content || '', 'utf8');
    res.json({ ok: true, path: p });
  } catch (e) { res.status(400).json({ error: e.message }); }
});

app.get('/api/dashboard/files', (req, res) => {
  const dir = DASHBOARD_PUBLIC;
  const items = fs.readdirSync(dir, { withFileTypes: true }).map(d => ({ name: d.name, type: d.isDirectory() ? 'dir' : 'file', path: path.join(dir, d.name) }));
  res.json({ dir, items });
});
app.get('/api/dashboard/file', (req, res) => {
  try {
    const p = ensureWithinRoot(req.query.path || '', DASHBOARD_PUBLIC);
    res.json({ path: p, content: readTextSafe(p, '') });
  } catch (e) { res.status(400).json({ error: e.message }); }
});
app.put('/api/dashboard/file', (req, res) => {
  try {
    const p = ensureWithinRoot(req.body?.path || '', DASHBOARD_PUBLIC);
    fs.writeFileSync(p, req.body?.content || '', 'utf8');
    res.json({ ok: true, path: p });
  } catch (e) { res.status(400).json({ error: e.message }); }
});

// Lightweight compatibility endpoints for VPS-oriented dashboard widgets
app.get('/api/usage/all', (req, res) => res.json({ totalTokens: 0, totalCost: 0, sessions: 0, byModel: [] }));
app.get('/api/updates/cli', (req, res) => res.json({ status: 'ok', current: 'quickclaw-v2', latest: 'quickclaw-v2', canUpgrade: false }));
app.post('/api/updates/cli/upgrade', (req, res) => res.json({ ok: false, message: 'Local mode: automatic CLI upgrade not enabled in QuickClaw V2.' }));
app.get(['/api/updates/workspace/', '/api/updates/workspace/:id'], (req, res) => res.json({ ok: true, mode: 'local', items: [] }));
app.get('/api/security/audit', (req, res) => res.json({ ok: true, score: 80, findings: [{ level: 'info', message: 'Local mode audit baseline loaded.' }] }));
app.post('/api/security/fix', (req, res) => res.json({ ok: false, message: 'Automated security fixes are disabled in local mode.' }));

app.get('/api/antfarm/status', (req, res) => res.json({ installed: false, running: false, mode: 'local' }));
app.get(['/api/antfarm/runs', '/api/antfarm/runs/'], (req, res) => res.json({ runs: [] }));
app.get('/api/antfarm/version', (req, res) => res.json({ version: null, installed: false }));
app.post('/api/antfarm/update', (req, res) => res.json({ ok: false, message: 'Antfarm update not configured.' }));
app.post('/api/antfarm/rollback', (req, res) => res.json({ ok: false, message: 'No antfarm rollback target found.' }));
app.post('/api/antfarm/run', (req, res) => res.json({ ok: false, message: 'Antfarm run endpoint not configured in local mode.' }));
app.post('/api/antfarm/dashboard/start', (req, res) => res.json({ ok: false, message: 'Antfarm dashboard unavailable in local mode.' }));
app.post('/api/antfarm/dashboard/stop', (req, res) => res.json({ ok: false, message: 'Antfarm dashboard unavailable in local mode.' }));

app.get('/api/news', (req, res) => res.json({ items: [], mode: 'stub' }));
app.get('/api/news/bookmarks', (req, res) => res.json({ items: [] }));
app.get('/api/news/quality', (req, res) => res.json({ score: null, message: 'No news analyzer configured.' }));
app.post('/api/news/fetch', (req, res) => res.json({ ok: false, message: 'News fetch is disabled in local mode.' }));
app.post('/api/news/feedback', (req, res) => res.json({ ok: true }));
app.put('/api/news/sources', (req, res) => res.json({ ok: true }));
app.put('/api/news', (req, res) => res.json({ ok: true }));

app.get('/api/versions', (req, res) => res.json({ versions: [{ id: 'current', label: 'Current working tree' }] }));
app.get('/api/versions/', (req, res) => res.json({ versions: [{ id: 'current', label: 'Current working tree' }] }));
app.post('/api/versions/snapshot', (req, res) => res.json({ ok: false, message: 'Snapshots not configured yet in local mode.' }));

app.get('*', (req, res) => {
  res.sendFile(path.join(DASHBOARD_PUBLIC, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`QuickClaw Dashboard running at http://localhost:${PORT}`);
  console.log(`QuickClaw root: ${QUICKCLAW_ROOT}`);
});
