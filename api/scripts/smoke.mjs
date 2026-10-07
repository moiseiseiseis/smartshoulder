// Prueba de humo de punta a punta contra la API corriendo (requiere el seed demo).
//   node scripts/smoke.mjs [http://localhost:3001]
// Ojo: crea un paciente y una sesión nuevos (vuelve a correr el seed para limpiar).
const API = process.argv[2] ?? 'http://localhost:3001';
let failures = 0;

async function call(method, path, { token, body } = {}) {
  const res = await fetch(API + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: res.status, data };
}

function check(name, cond, extra = '') {
  console.log(`${cond ? '✓' : '✗'} ${name}${extra ? `  — ${extra}` : ''}`);
  if (!cond) failures++;
}

// ---------- Fisio ----------
const login = await call('POST', '/auth/login', { body: { email: 'fisio@demo.mx', password: 'demo1234' } });
check('login fisio', login.status === 201 && login.data.token);
const physio = login.data.token;
check('contraseña incorrecta rechazada', (await call('POST', '/auth/login', { body: { email: 'fisio@demo.mx', password: 'xxxxxxxx' } })).status === 401);
check('sin token → 401', (await call('GET', '/patients')).status === 401);

const list = await call('GET', '/patients', { token: physio });
check('lista de pacientes', list.status === 200 && list.data.length === 6, `${list.data.length} pacientes`);
for (const p of list.data) {
  console.log(`    ${p.alerts.length ? '⚠' : ' '} ${p.displayName.padEnd(24)} ${String(p.adherence7 ?? '-').padStart(3)}%  ${p.primarySource.padEnd(8)} ${p.device ?? '—'}  ${p.alerts.map((a) => a.type).join(', ')}`);
}
const maria = list.data.find((p) => p.displayName === 'María González');
const ana = list.data.find((p) => p.displayName === 'Ana López');
check('María: alerta sin sesión', maria.alerts.some((a) => a.type === 'NO_SESSION'));
check('Ana: sin alertas', ana.alerts.length === 0, `${ana.adherence7}%`);
check('orden: con alertas primero', list.data[0].alerts.length >= list.data.at(-1).alerts.length);

const detail = await call('GET', `/patients/${maria.id}/adherence`, { token: physio });
check('detalle de apego', detail.status === 200 && detail.data.calendar.length === 42);
check('María se salta la rotación externa (ID 3)', detail.data.mostSkipped === 3, `mostSkipped=${detail.data.mostSkipped}`);
check('verificado y reportado separados', detail.data.period.reported.adherencePct === null && detail.data.period.verified.sessions > 0);

const kpis = await call('GET', '/clinic/kpis', { token: physio });
check('KPIs de clínica', kpis.status === 200, JSON.stringify(kpis.data.avgAdherence7) + ' relojes ' + JSON.stringify(kpis.data.devices));

const csv = await call('GET', `/patients/${maria.id}/export.csv`, { token: physio });
check('export CSV', csv.status === 200 && String(csv.data).includes('verificado por el dispositivo'));

const templates = await call('GET', '/templates', { token: physio });
const devices = await call('GET', '/devices', { token: physio });
const free = devices.data.find((d) => d.status === 'AVAILABLE');
check('plantillas y relojes', templates.data.length === 2 && !!free, `libre: ${free?.bleName}`);

const created = await call('POST', '/patients', {
  token: physio,
  body: { displayName: 'Paciente de prueba', affectedArm: 'LEFT', diagnosis: 'Prueba de humo', prescription: { templateId: templates.data[0].id }, deviceId: free.id },
});
check('alta en un paso (plantilla + reloj + invitación)', created.status === 201 && created.data.invite.code.length === 6, created.data.invite?.qr);
const busy = await call('POST', '/patients', {
  token: physio,
  body: { displayName: 'Otro', affectedArm: 'LEFT', diagnosis: 'x y', prescription: { templateId: templates.data[0].id }, deviceId: free.id },
});
check('no se puede asignar un reloj ocupado', busy.status === 400);
const ret = await call('POST', `/devices/${free.id}/return`, { token: physio });
const after = (await call('GET', '/devices', { token: physio })).data.find((d) => d.id === free.id);
check('devolución → limpieza', ret.status === 201 && after.status === 'CLEANING');
check('validación de datos', (await call('POST', '/patients', { token: physio, body: { displayName: 'x' } })).status === 400);

// ---------- Paciente (app) ----------
const redeem = await call('POST', '/auth/redeem', { body: { code: 'demo23' } });
check('app: entrar con código DEMO23', redeem.status === 201);
const patient = redeem.data.token;
check('código inválido rechazado', (await call('POST', '/auth/redeem', { body: { code: 'ZZZZZZ' } })).status === 401);
check('paciente no ve la lista del fisio', (await call('GET', '/patients', { token: patient })).status === 403);

const me = await call('GET', '/me', { token: patient });
check('app: /me', me.status === 200 && me.data.device?.bleName === 'SS-54F5' && me.data.prescription.exercises.length === 2);

const now = Date.now();
const body = {
  clientSessionId: `smoke-${now}`,
  prescriptionId: me.data.prescription.id,
  source: 'VERIFIED',
  deviceBleName: 'SS-54F5',
  fwVersion: 1,
  modelVersion: 0,
  deviceBattery: 88,
  startedAt: new Date(now - 300_000).toISOString(),
  endedAt: new Date(now).toISOString(),
  endedEarly: false,
  painScore: 2,
  effortScore: 5,
  results: [{ exerciseId: 1, setsDone: 1, repsDone: 5 }, { exerciseId: 2, setsDone: 1, repsDone: 5 }],
  events: [{ seq: 0, type: 1, exerciseId: 1, repIndex: 1, confidence: 240, deviceTimestampMs: 2100 }],
};
const s1 = await call('POST', '/sessions', { token: patient, body });
const s2 = await call('POST', '/sessions', { token: patient, body });
check('app: subir sesión (backend la marca completa)', s1.status === 201 && s1.data.status === 'COMPLETE');
check('app: reintento no duplica', s2.data.duplicate === true && s2.data.id === s1.data.id);
check('sesión verificada sin reloj rechazada', (await call('POST', '/sessions', { token: patient, body: { ...body, clientSessionId: `x-${now}`, deviceBleName: undefined } })).status === 400);

const hist = await call('GET', '/me/sessions', { token: patient });
check('app: historial y racha', hist.status === 200 && hist.data.streak >= 1, `racha ${hist.data.streak}`);

const live = (await call('GET', '/patients', { token: physio })).data.find((p) => p.displayName === 'Paciente demo en vivo');
check('fisio ve la sesión en vivo', live.lastSessionAt !== null, `apego 7d ${live.adherence7}%`);

console.log(failures ? `\n${failures} fallas` : '\nTodo bien');
process.exit(failures ? 1 : 0);
