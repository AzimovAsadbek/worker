/**
 * Demo data for development / pilot demos. All people and phone numbers are fictional.
 * Refuses to run in production unless SEED_ALLOW_PRODUCTION=true.
 *
 *   npm run seed
 *
 * Demo accounts (OTP = OTP_DEV_CODE, e.g. 111111, when SMS_PROVIDER=dev):
 *   +998 90 000 00 01  Company admin  (Taraqqiyot Construction)
 *   +998 90 000 00 02  Foreman        (Yangiqo'rg'on)
 *   +998 90 000 00 03  Foreman        (Namangan)
 *   +998 90 000 01 01…16  Workers
 *   +998 90 000 02 01  Job seeker (no company yet)
 */
/* eslint-disable no-console -- CLI script output */
import { existsSync } from 'fs';
import { resolve } from 'path';
import { EventSource, PaymentPeriod, Prisma, PrismaClient, Role, ShiftStatus, TaskStatus, User, VacancyStatus, WorkEventType } from '@prisma/client';

for (const file of [resolve(__dirname, '../.env'), resolve(__dirname, '../../.env')]) {
  if (existsSync(file)) process.loadEnvFile(file);
}
if (process.env.NODE_ENV === 'production' && process.env.SEED_ALLOW_PRODUCTION !== 'true') {
  console.error('Refusing to seed demo data in production.');
  process.exit(1);
}

const prisma = new PrismaClient();
const TZ_OFFSET_H = 5; // Asia/Tashkent
const COMPANY_NAME = 'Taraqqiyot Construction';

// deterministic pseudo-random so the demo looks the same every time
let seed = 42;
const rnd = () => {
  seed = (seed * 1103515245 + 12345) % 2 ** 31;
  return seed / 2 ** 31;
};

const ymd = (d: Date) => d.toISOString().slice(0, 10);
/** Local (UTC+5) wall clock → UTC Date. */
const local = (day: string, hh: number, mm: number) => new Date(Date.UTC(+day.slice(0, 4), +day.slice(5, 7) - 1, +day.slice(8, 10), hh - TZ_OFFSET_H, mm));
const localToday = () => ymd(new Date(Date.now() + TZ_OFFSET_H * 3600_000));
const addDays = (day: string, n: number) => ymd(new Date(Date.parse(`${day}T00:00:00Z`) + n * 86400_000));
const isoDow = (day: string) => ((new Date(`${day}T00:00:00Z`).getUTCDay() + 6) % 7) + 1;

const WORKERS: [string, string][] = [
  ['Aziz Karimov', "G'isht teruvchi"],
  ['Bekzod Tursunov', 'Betonchi'],
  ['Doston Yusupov', 'Armaturachi'],
  ['Eldor Rahimov', 'Payvandchi'],
  ['Farrux Qodirov', 'Oddiy ishchi'],
  ['Jasur Aliyev', "G'isht teruvchi"],
  ['Kamol Ismoilov', 'Suvoqchi'],
  ['Laziz Nurmatov', 'Elektrik'],
  ['Mirzo Sobirov', 'Duradgor'],
  ['Nodir Xolmatov', 'Oddiy ishchi'],
  ['Otabek Salimov', 'Kafelchi'],
  ['Rustam Ergashev', 'Betonchi'],
  ['Sardor Mahmudov', 'Santexnik'],
  ["Shoxrux G'aniyev", "Bo'yoqchi"],
  ['Umid Hamidov', 'Oddiy ishchi'],
  ['Zafar Abdullayev', 'Kran operatori'],
];

async function main() {
  if (await prisma.company.findFirst({ where: { name: COMPANY_NAME } })) {
    console.log(`Demo data already present ("${COMPANY_NAME}"). Nothing to do.`);
    return;
  }

  const phone = (n: string) => `+99890000${n}`;
  const admin = await prisma.user.upsert({ where: { phone: phone('0001') }, create: { phone: phone('0001'), fullName: 'Akmal Toshpulatov' }, update: {} });
  const foreman1 = await prisma.user.upsert({ where: { phone: phone('0002') }, create: { phone: phone('0002'), fullName: 'Bahodir Mirzayev' }, update: {} });
  const foreman2 = await prisma.user.upsert({ where: { phone: phone('0003') }, create: { phone: phone('0003'), fullName: 'Sherzod Qosimov' }, update: {} });
  const seeker = await prisma.user.upsert({
    where: { phone: phone('0201') },
    create: {
      phone: phone('0201'),
      fullName: 'Ilhom Oripov',
      workerProfile: { create: { primaryTrade: "G'isht teruvchi", trades: ["G'isht teruvchi", 'Suvoqchi'], selfReportedExperienceYears: 4, city: 'Namangan', region: 'Namangan viloyati' } },
    },
    update: {},
  });
  const workers: User[] = [];
  for (let i = 0; i < WORKERS.length; i++) {
    const [fullName, trade] = WORKERS[i];
    const p = phone(`01${String(i + 1).padStart(2, '0')}`);
    workers.push(
      await prisma.user.upsert({
        where: { phone: p },
        create: {
          phone: p,
          fullName,
          workerProfile: { create: { primaryTrade: trade, trades: [trade], selfReportedExperienceYears: 1 + Math.floor(rnd() * 10), region: 'Namangan viloyati', city: 'Namangan' } },
        },
        update: {},
      }),
    );
  }

  const company = await prisma.company.create({
    data: {
      name: COMPANY_NAME,
      industry: 'CONSTRUCTION',
      description: "Namangan viloyatida turar-joy va tijorat binolari quruvchi kompaniya.",
      phone: '+998692000000',
      region: 'Namangan viloyati',
      city: 'Namangan',
      address: "Namangan sh., Uychi ko'chasi",
      createdById: admin.id,
    },
  });
  const cid = company.id;
  await prisma.companyMembership.createMany({
    data: [
      { companyId: cid, userId: admin.id, role: Role.COMPANY_ADMIN },
      { companyId: cid, userId: foreman1.id, role: Role.FOREMAN, title: 'Katta prorab', invitedById: admin.id },
      { companyId: cid, userId: foreman2.id, role: Role.FOREMAN, title: 'Prorab', invitedById: admin.id },
      ...workers.map((w, i) => ({ companyId: cid, userId: w.id, role: Role.WORKER, title: WORKERS[i][1], invitedById: admin.id })),
    ],
  });

  const p1 = await prisma.project.create({
    data: { companyId: cid, name: "Yangiqo'rg'on Residential Complex", description: '9 qavatli 3 ta turar-joy binosi', address: "Yangiqo'rg'on tumani", status: 'ACTIVE', startDate: new Date('2026-03-01'), createdById: admin.id },
  });
  const p2 = await prisma.project.create({
    data: { companyId: cid, name: 'Namangan Commercial Center', description: "4 qavatli savdo markazi", address: 'Namangan shahri, Mustaqillik ko\'chasi', status: 'ACTIVE', startDate: new Date('2026-05-15'), createdById: admin.id },
  });
  const site1 = await prisma.site.create({
    data: { companyId: cid, projectId: p1.id, name: "Yangiqo'rg'on Residential Complex — Blok A", address: "Yangiqo'rg'on tumani markazi", latitude: 41.1902, longitude: 71.7236, radiusMeters: 250, shiftStart: '08:00', shiftEnd: '18:00', createdById: admin.id },
  });
  const site2 = await prisma.site.create({
    data: { companyId: cid, projectId: p2.id, name: 'Namangan Commercial Center', address: 'Namangan shahri', latitude: 40.9983, longitude: 71.6726, radiusMeters: 200, shiftStart: '08:00', shiftEnd: '17:00', createdById: admin.id },
  });

  const site1Workers = workers.slice(0, 10);
  const site2Workers = workers.slice(10);
  const assignmentStart = new Date(Date.now() - 30 * 86400_000);
  await prisma.siteAssignment.createMany({
    data: [
      { companyId: cid, siteId: site1.id, userId: foreman1.id, role: Role.FOREMAN, assignedById: admin.id, startDate: assignmentStart },
      { companyId: cid, siteId: site2.id, userId: foreman2.id, role: Role.FOREMAN, assignedById: admin.id, startDate: assignmentStart },
      ...site1Workers.map((w, i) => ({ companyId: cid, siteId: site1.id, userId: w.id, role: Role.WORKER, isResident: i < 3, assignedById: foreman1.id, startDate: assignmentStart })),
      ...site2Workers.map((w) => ({ companyId: cid, siteId: site2.id, userId: w.id, role: Role.WORKER, assignedById: foreman2.id, startDate: assignmentStart })),
    ],
  });

  // ───── work history: last 14 days ─────
  const today = localToday();
  let shiftCount = 0;
  const addShift = async (
    site: typeof site1,
    worker: (typeof workers)[number],
    foreman: typeof foreman1,
    day: string,
    opts: { start: Date; end: Date | null; status: ShiftStatus; resident: boolean; flags?: string[] },
  ) => {
    const worked = opts.end ? Math.round((opts.end.getTime() - opts.start.getTime()) / 60000) : 0;
    const scheduled = local(day, 8, 0);
    const lateBy = Math.floor((opts.start.getTime() - scheduled.getTime()) / 60000);
    const isLate = lateBy > site.lateGraceMinutes;
    const verified = opts.status === ShiftStatus.VERIFIED ? Math.max(0, worked - 60) : 0;
    const shift = await prisma.shift.create({
      data: {
        companyId: cid,
        siteId: site.id,
        workerId: worker.id,
        businessDate: new Date(`${day}T00:00:00Z`),
        startedAt: opts.start,
        originalStartAt: opts.start,
        endedAt: opts.end,
        originalEndAt: opts.end,
        status: opts.status,
        isResident: opts.resident,
        isLate,
        lateMinutes: isLate ? lateBy : 0,
        workedMinutes: opts.status === ShiftStatus.NEEDS_REVIEW ? 0 : worked,
        breakMinutes: opts.status === ShiftStatus.VERIFIED ? 60 : 0,
        verifiedMinutes: verified,
        verifiedById: opts.status === ShiftStatus.VERIFIED ? foreman.id : null,
        verifiedAt: opts.status === ShiftStatus.VERIFIED && opts.end ? new Date(opts.end.getTime() + 3600_000) : null,
        flags: opts.flags ?? [],
      },
    });
    const jitter = () => (rnd() - 0.5) * 0.001;
    const base = { companyId: cid, siteId: site.id, shiftId: shift.id, subjectUserId: worker.id };
    const events: Prisma.WorkEventCreateManyInput[] = [
      {
        ...base,
        actorUserId: worker.id,
        type: WorkEventType.WORK_STARTED,
        source: EventSource.MOBILE_APP,
        occurredAt: opts.start,
        receivedAt: opts.start,
        clientEventId: `seed-${shift.id}-s`,
        latitude: site.latitude + jitter(),
        longitude: site.longitude + jitter(),
        accuracyMeters: opts.flags?.includes('LOW_ACCURACY') ? 120 + Math.round(rnd() * 60) : 8 + Math.round(rnd() * 25),
        insideGeofence: true,
        distanceMeters: Math.round(rnd() * 80),
        deviceId: `seed-device-${worker.id.slice(0, 8)}`,
        flags: opts.flags ?? [],
      },
    ];
    if (opts.end) {
      events.push({
        ...base,
        actorUserId: worker.id,
        type: WorkEventType.WORK_ENDED,
        source: EventSource.MOBILE_APP,
        occurredAt: opts.end,
        receivedAt: opts.end,
        clientEventId: `seed-${shift.id}-e`,
        latitude: site.latitude + jitter(),
        longitude: site.longitude + jitter(),
        accuracyMeters: 8 + Math.round(rnd() * 25),
        insideGeofence: true,
        distanceMeters: Math.round(rnd() * 80),
        deviceId: `seed-device-${worker.id.slice(0, 8)}`,
        metadata: { workedMinutes: worked },
      });
    }
    if (opts.status === ShiftStatus.VERIFIED) {
      events.push({ ...base, actorUserId: foreman.id, type: WorkEventType.SHIFT_VERIFIED, source: EventSource.FOREMAN_APP, occurredAt: new Date(opts.end!.getTime() + 3600_000), metadata: { verifiedMinutes: verified, breakMinutes: 60 } });
    }
    if (opts.status === ShiftStatus.NEEDS_REVIEW) {
      events.push({ ...base, actorUserId: worker.id, type: WorkEventType.SHIFT_AUTO_CLOSED, source: EventSource.SYSTEM, occurredAt: new Date(opts.start.getTime() + 24 * 3600_000), reason: 'Missed checkout: new check-in on a later day', flags: ['MISSED_CHECKOUT'] });
    }
    await prisma.workEvent.createMany({ data: events });
    shiftCount++;
    return shift;
  };

  // Most recent working day at least 2 days ago → demo "missed checkout" (resident worker) case.
  let missedCheckoutDaysBack = 2;
  while (isoDow(addDays(today, -missedCheckoutDaysBack)) === 7) missedCheckoutDaysBack++;

  for (const [site, crew, foreman, endHour] of [
    [site1, site1Workers, foreman1, 18],
    [site2, site2Workers, foreman2, 17],
  ] as const) {
    for (let back = 14; back >= 0; back--) {
      const day = addDays(today, -back);
      if (isoDow(day) === 7) continue; // Sunday off
      for (let wi = 0; wi < crew.length; wi++) {
        const worker = crew[wi];
        const resident = site.id === site1.id && wi < 3;
        if (rnd() < 0.08 && !(back === missedCheckoutDaysBack && wi === 1 && resident)) continue; // absent
        const startMin = -15 + Math.floor(rnd() * 45) + (rnd() < 0.1 ? 30 : 0);
        const start = local(day, 8, 0 + startMin);
        const end = local(day, endHour, Math.floor(rnd() * 30) - 10);
        if (back === 0) {
          // today: most are on site right now, nobody has checked out yet
          if (start.getTime() < Date.now()) await addShift(site, worker, foreman, day, { start, end: null, status: ShiftStatus.OPEN, resident });
          continue;
        }
        if (back === missedCheckoutDaysBack && wi === 1 && resident) {
          await addShift(site, worker, foreman, day, { start, end: null, status: ShiftStatus.NEEDS_REVIEW, resident, flags: ['MISSED_CHECKOUT'] });
          continue;
        }
        const status = back <= 2 ? ShiftStatus.CLOSED : ShiftStatus.VERIFIED;
        const flags = rnd() < 0.05 ? ['LOW_ACCURACY'] : [];
        await addShift(site, worker, foreman, day, { start, end, status, resident, flags });
      }
    }
  }

  // one open dispute on a closed shift
  const disputed = await prisma.shift.findFirst({ where: { companyId: cid, status: ShiftStatus.CLOSED, siteId: site2.id }, orderBy: { startedAt: 'asc' } });
  if (disputed && disputed.endedAt) {
    const d = await prisma.dispute.create({
      data: { companyId: cid, shiftId: disputed.id, openedById: disputed.workerId, reason: "Men 18:00 gacha ishladim, lekin ilova erta yakunlangan deb ko'rsatyapti.", claimedEnd: new Date(disputed.endedAt.getTime() + 45 * 60_000) },
    });
    await prisma.workEvent.create({
      data: { companyId: cid, siteId: disputed.siteId, shiftId: disputed.id, subjectUserId: disputed.workerId, actorUserId: disputed.workerId, type: WorkEventType.DISPUTE_OPENED, source: EventSource.MOBILE_APP, occurredAt: new Date(), entityType: 'Dispute', entityId: d.id, reason: d.reason },
    });
  }

  // ───── tasks ─────
  const taskDefs: [number, string, number, string, TaskStatus][] = [
    [0, "G'isht terish — 3-qavat, A seksiya", 20, 'm2', TaskStatus.APPROVED],
    [0, "G'isht terish — 4-qavat, A seksiya", 25, 'm2', TaskStatus.IN_PROGRESS],
    [1, 'Beton quyish — 3-qavat plitasi', 12, 'm3', TaskStatus.SUBMITTED],
    [2, "Armatura bog'lash — ustunlar", 40, 'pcs', TaskStatus.APPROVED],
    [6, 'Ichki devorlarni suvash — 2-qavat', 60, 'm2', TaskStatus.ASSIGNED],
    [10, 'Kafel yotqizish — hojatxonalar', 18, 'm2', TaskStatus.CHANGES_REQUESTED],
  ];
  for (const [wi, title, qty, unit, status] of taskDefs) {
    const worker = workers[wi];
    const site = wi < 10 ? site1 : site2;
    const reviewer = wi < 10 ? foreman1 : foreman2;
    const task = await prisma.task.create({
      data: {
        companyId: cid,
        siteId: site.id,
        assigneeId: worker.id,
        createdById: reviewer.id,
        title,
        quantity: qty,
        unit,
        status,
        dueDate: new Date(`${addDays(today, 5)}T00:00:00Z`),
        startedAt: status === TaskStatus.ASSIGNED ? null : new Date(Date.now() - 3 * 86400_000),
        submittedAt: [TaskStatus.SUBMITTED, TaskStatus.APPROVED, TaskStatus.CHANGES_REQUESTED].includes(status as never) ? new Date(Date.now() - 86400_000) : null,
        completedQuantity: [TaskStatus.SUBMITTED, TaskStatus.APPROVED].includes(status as never) ? qty : null,
        reviewedAt: [TaskStatus.APPROVED, TaskStatus.CHANGES_REQUESTED].includes(status as never) ? new Date() : null,
        reviewedById: [TaskStatus.APPROVED, TaskStatus.CHANGES_REQUESTED].includes(status as never) ? reviewer.id : null,
      },
    });
    const ev = (type: WorkEventType, actor: string) => ({ companyId: cid, siteId: site.id, subjectUserId: worker.id, actorUserId: actor, type, source: actor === worker.id ? EventSource.MOBILE_APP : EventSource.FOREMAN_APP, occurredAt: new Date(), entityType: 'Task', entityId: task.id });
    const evs = [ev(WorkEventType.TASK_ASSIGNED, reviewer.id)];
    if (status !== TaskStatus.ASSIGNED) evs.push(ev(WorkEventType.TASK_STARTED, worker.id));
    if (status === TaskStatus.APPROVED) {
      evs.push(ev(WorkEventType.TASK_SUBMITTED, worker.id), ev(WorkEventType.TASK_APPROVED, reviewer.id));
      await prisma.taskApproval.create({ data: { taskId: task.id, reviewerId: reviewer.id, decision: 'APPROVED' } });
    }
    if (status === TaskStatus.SUBMITTED) evs.push(ev(WorkEventType.TASK_SUBMITTED, worker.id));
    if (status === TaskStatus.CHANGES_REQUESTED) {
      evs.push(ev(WorkEventType.TASK_SUBMITTED, worker.id), ev(WorkEventType.TASK_CHANGES_REQUESTED, reviewer.id));
      await prisma.taskApproval.create({ data: { taskId: task.id, reviewerId: reviewer.id, decision: 'CHANGES_REQUESTED', comment: "Choklar notekis, qayta to'g'rilang" } });
    }
    await prisma.workEvent.createMany({ data: evs });
  }

  // ───── vacancies ─────
  const v1 = await prisma.vacancy.create({
    data: {
      companyId: cid, siteId: site1.id, createdById: foreman1.id, title: "Tajribali g'isht teruvchi kerak",
      description: "Yangiqo'rg'on turar-joy majmuasi, 9 qavatli bino. Kunlik to'lov, har hafta hisob-kitob. Yotoqxona beriladi.",
      category: 'BRICKLAYER', region: 'Namangan viloyati', city: "Yangiqo'rg'on", address: site1.address, latitude: site1.latitude, longitude: site1.longitude,
      rateAmount: 280000, paymentPeriod: PaymentPeriod.DAILY, workersNeeded: 4, startDate: new Date(`${addDays(today, 3)}T00:00:00Z`), durationDays: 90,
      requirements: "Kamida 2 yil tajriba. O'z asboblari bo'lsa afzal.", status: VacancyStatus.OPEN, publishedAt: new Date(Date.now() - 2 * 86400_000),
    },
  });
  await prisma.vacancy.create({
    data: {
      companyId: cid, siteId: site2.id, createdById: admin.id, title: 'Betonchi va armaturachilar',
      description: 'Savdo markazi karkas ishlari uchun betonchi va armaturachilar jamoasi kerak.',
      category: 'CONCRETE', region: 'Namangan viloyati', city: 'Namangan', address: site2.address, latitude: site2.latitude, longitude: site2.longitude,
      rateAmount: 250000, paymentPeriod: PaymentPeriod.DAILY, workersNeeded: 6, startDate: new Date(`${addDays(today, 7)}T00:00:00Z`), durationDays: 120,
      status: VacancyStatus.OPEN, publishedAt: new Date(Date.now() - 86400_000),
    },
  });
  await prisma.vacancy.create({
    data: {
      companyId: cid, siteId: site2.id, createdById: admin.id, title: 'Elektrik (ichki montaj)',
      description: "Savdo markazi ichki elektr montaji. Oylik maosh, rasmiy ishga joylashtirish.",
      category: 'ELECTRICIAN', region: 'Namangan viloyati', city: 'Namangan', rateAmount: 6500000, paymentPeriod: PaymentPeriod.MONTHLY, workersNeeded: 2,
      requirements: 'Elektr xavfsizligi guruhi (III+).', status: VacancyStatus.DRAFT,
    },
  });
  await prisma.application.create({ data: { vacancyId: v1.id, companyId: cid, workerId: seeker.id, coverNote: "4 yil tajribam bor, Namanganda yashayman. Ertadan boshlay olaman." } });

  await prisma.auditLog.createMany({
    data: [
      { companyId: cid, actorUserId: admin.id, action: 'COMPANY_CREATED', entityType: 'Company', entityId: cid, metadata: { seed: true } },
      { companyId: cid, actorUserId: admin.id, action: 'SITE_CREATED', entityType: 'Site', entityId: site1.id, metadata: { seed: true } },
      { companyId: cid, actorUserId: admin.id, action: 'SITE_CREATED', entityType: 'Site', entityId: site2.id, metadata: { seed: true } },
      { companyId: cid, actorUserId: admin.id, action: 'VACANCY_CREATED', entityType: 'Vacancy', entityId: v1.id, metadata: { seed: true } },
    ],
  });

  console.log(`Seeded "${COMPANY_NAME}": 2 projects, 2 sites, 2 foremen, ${workers.length} workers, ${shiftCount} shifts, ${taskDefs.length} tasks, 3 vacancies.`);
  console.log('Demo logins (OTP = OTP_DEV_CODE): admin +998900000001, foreman +998900000002, worker +998900000101, job seeker +998900000201');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
