// ===========================================================================
// QuickClaw Dashboard — server.js v2
// Express server for the QuickClaw management dashboard
// https://github.com/guyingoldglasses/QuickClaw
// ===========================================================================

const express = require('express');
const { execSync, exec } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

const app = express();
const PORT = process.env.DASHBOARD_PORT || 3000;

// QuickClaw root directory (passed via env or inferred)
const QUICKCLAW_ROOT = process.env.QUICKCLAW_ROOT || path.resolve(__dirname, '..');
const INSTALL_DIR = path.join(QUICKCLAW_ROOT, 'openclaw');
const CONFIG_DIR = path.join(INSTALL_DIR, 'config');
const LOG_DIR = path.join(QUICKCLAW_ROOT, 'logs');
const PID_DIR = path.join(QUICKCLAW_ROOT, '.pids');

// ---------------------------------------------------------------------------
// Middleware
// ---------------------------------------------------------------------------
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function fileExists(filePath) {
    try {
        return fs.existsSync(filePath);
    } catch {
        return false;
    }
}

function readPidFile(name) {
    const pidFile = path.join(PID_DIR, `${name}.pid`);
    if (!fileExists(pidFile)) return null;
    try {
        const pid = parseInt(fs.readFileSync(pidFile, 'utf8').trim(), 10);
        if (isNaN(pid)) return null;
        // Check if process is alive
        try {
            process.kill(pid, 0);
            return pid;
        } catch {
            return null; // stale PID
        }
    } catch {
        return null;
    }
}

function getLogTail(logFile, lines = 50) {
    const fullPath = path.join(LOG_DIR, logFile);
    if (!fileExists(fullPath)) return [];
    try {
        const output = execSync(`tail -${lines} "${fullPath}" 2>/dev/null`, {
            encoding: 'utf8',
            timeout: 5000
        });
        return output.split('\n').filter(Boolean);
    } catch {
        return [];
    }
}

function checkPort(port) {
    try {
        execSync(`lsof -i :${port}`, { encoding: 'utf8', timeout: 3000 });
        return true;
    } catch {
        return false;
    }
}

function readConfig() {
    const configPath = path.join(CONFIG_DIR, 'default.yaml');
    if (!fileExists(configPath)) return null;
    try {
        return fs.readFileSync(configPath, 'utf8');
    } catch {
        return null;
    }
}

// ---------------------------------------------------------------------------
// API: Health endpoint
// ---------------------------------------------------------------------------
app.get('/api/health', (req, res) => {
    const gatewayPid = readPidFile('gateway');
    const dashboardUp = true; // If we're responding, we're up

    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        version: '2.0.0',
        dashboard: {
            running: dashboardUp,
            port: PORT
        },
        gateway: {
            running: !!gatewayPid,
            pid: gatewayPid,
            port: 5000,
            portListening: checkPort(5000)
        },
        system: {
            platform: os.platform(),
            arch: os.arch(),
            nodeVersion: process.version,
            uptime: Math.floor(process.uptime())
        }
    });
});

// ---------------------------------------------------------------------------
// API: Status overview
// ---------------------------------------------------------------------------
app.get('/api/status', (req, res) => {
    const gatewayPid = readPidFile('gateway');
    const configExists = fileExists(path.join(CONFIG_DIR, 'default.yaml'));

    res.json({
        gateway: {
            running: !!gatewayPid,
            pid: gatewayPid,
            portActive: checkPort(5000)
        },
        dashboard: {
            running: true,
            pid: process.pid,
            port: PORT
        },
        install: {
            path: INSTALL_DIR,
            exists: fileExists(INSTALL_DIR),
            configExists: configExists
        }
    });
});

// ---------------------------------------------------------------------------
// API: Logs
// ---------------------------------------------------------------------------
app.get('/api/logs/:service', (req, res) => {
    const { service } = req.params;
    const lines = Math.min(parseInt(req.query.lines) || 50, 200);

    const validServices = ['gateway', 'dashboard'];
    if (!validServices.includes(service)) {
        return res.status(400).json({ error: 'Invalid service name' });
    }

    const logLines = getLogTail(`${service}.log`, lines);
    res.json({ service, lines: logLines, count: logLines.length });
});

// ---------------------------------------------------------------------------
// API: Config (read-only)
// ---------------------------------------------------------------------------
app.get('/api/config', (req, res) => {
    const config = readConfig();
    if (config) {
        res.json({ exists: true, content: config });
    } else {
        res.json({ exists: false, content: null });
    }
});

// ---------------------------------------------------------------------------
// API: Add-ons / Integrations status
// ---------------------------------------------------------------------------
app.get('/api/addons', (req, res) => {
    const config = readConfig() || '';

    // Check for each integration's presence in config or environment
    const addons = {
        openai: {
            name: 'OpenAI',
            description: 'GPT model access via API key',
            status: getAddonStatus('openai', config),
            configHint: 'Add your OpenAI API key to openclaw/config/default.yaml under openai.api_key'
        },
        ftp: {
            name: 'FTP',
            description: 'File transfer for remote deployments',
            status: getAddonStatus('ftp', config),
            configHint: 'Add FTP settings (host, user, pass) to config under ftp section'
        },
        email: {
            name: 'Email',
            description: 'Email notifications and alerts',
            status: getAddonStatus('email', config),
            configHint: 'Add SMTP settings to config under email section'
        },
        skills: {
            name: 'Skills Bundle',
            description: 'Extended capabilities and tools',
            status: getSkillsStatus(),
            configHint: 'Install skills via: open-claw skills install <bundle>'
        }
    };

    res.json(addons);
});

function getAddonStatus(addon, configContent) {
    // Check environment variables first
    const envMap = {
        openai: 'OPENAI_API_KEY',
        ftp: 'FTP_HOST',
        email: 'SMTP_HOST'
    };

    if (envMap[addon] && process.env[envMap[addon]]) {
        return 'enabled';
    }

    // Check config file for section
    if (configContent.includes(`${addon}:`)) {
        // Check if it has actual values (not just the section header)
        const sectionRegex = new RegExp(`${addon}:[\\s\\S]*?(?=\\n\\w|$)`, 'm');
        const match = configContent.match(sectionRegex);
        if (match && match[0].includes('api_key') || match && match[0].includes('host')) {
            return 'needs_config'; // Section exists but may need values
        }
        return 'needs_config';
    }

    return 'missing';
}

function getSkillsStatus() {
    const skillsDir = path.join(INSTALL_DIR, 'skills');
    if (!fileExists(skillsDir)) return 'missing';
    try {
        const contents = fs.readdirSync(skillsDir);
        return contents.length > 0 ? 'enabled' : 'needs_config';
    } catch {
        return 'missing';
    }
}

// ---------------------------------------------------------------------------
// API: Start gateway
// ---------------------------------------------------------------------------
app.post('/api/gateway/start', (req, res) => {
    const existingPid = readPidFile('gateway');
    if (existingPid) {
        return res.json({ success: false, message: 'Gateway already running', pid: existingPid });
    }

    try {
        const configPath = path.join(CONFIG_DIR, 'default.yaml');
        const configFlag = fileExists(configPath) ? `--config "${configPath}"` : '';
        const logPath = path.join(LOG_DIR, 'gateway.log');

        // Ensure log dir exists
        if (!fileExists(LOG_DIR)) {
            fs.mkdirSync(LOG_DIR, { recursive: true });
        }

        // Prefer local install first, then global CLI, then npx from INSTALL_DIR
        const localOpenClaw = path.join(INSTALL_DIR, 'node_modules', '.bin', 'open-claw');
        const localOpenclaw = path.join(INSTALL_DIR, 'node_modules', '.bin', 'openclaw');

        let cmd;
        let cwd = QUICKCLAW_ROOT;

        if (fileExists(localOpenClaw)) {
            cmd = `"${localOpenClaw}" start ${configFlag}`;
        } else if (fileExists(localOpenclaw)) {
            cmd = `"${localOpenclaw}" start ${configFlag}`;
        } else {
            try {
                execSync('which open-claw', { encoding: 'utf8' });
                cmd = `open-claw start ${configFlag}`;
            } catch {
                try {
                    execSync('which openclaw', { encoding: 'utf8' });
                    cmd = `openclaw start ${configFlag}`;
                } catch {
                    cmd = `npx open-claw start ${configFlag}`;
                    cwd = INSTALL_DIR;
                }
            }
        }

        const child = exec(`${cmd} >> "${logPath}" 2>&1`, { cwd });
        if (child.pid) {
            // Ensure PID dir exists
            if (!fileExists(PID_DIR)) {
                fs.mkdirSync(PID_DIR, { recursive: true });
            }
            fs.writeFileSync(path.join(PID_DIR, 'gateway.pid'), String(child.pid));
            child.unref();
        }

        res.json({ success: true, message: 'Gateway starting...', pid: child.pid });
    } catch (err) {
        res.json({ success: false, message: `Failed to start: ${err.message}` });
    }
});

// ---------------------------------------------------------------------------
// API: Stop gateway
// ---------------------------------------------------------------------------
app.post('/api/gateway/stop', (req, res) => {
    const pid = readPidFile('gateway');
    if (!pid) {
        return res.json({ success: false, message: 'Gateway not running' });
    }

    try {
        process.kill(pid, 'SIGTERM');
        // Clean up PID file
        const pidFile = path.join(PID_DIR, 'gateway.pid');
        if (fileExists(pidFile)) fs.unlinkSync(pidFile);

        res.json({ success: true, message: 'Gateway stopped', pid });
    } catch (err) {
        res.json({ success: false, message: `Failed to stop: ${err.message}` });
    }
});

// ---------------------------------------------------------------------------
// Fallback: serve index.html for SPA-style routing
// ---------------------------------------------------------------------------
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ---------------------------------------------------------------------------
// Start server
// ---------------------------------------------------------------------------
app.listen(PORT, () => {
    console.log(`QuickClaw Dashboard v2 running at http://localhost:${PORT}`);
    console.log(`QuickClaw root: ${QUICKCLAW_ROOT}`);
});
