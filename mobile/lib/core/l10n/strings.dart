/// Uzbek (Latin) UI strings. Uzbek-first; the structure allows adding ru/en later.
class S {
  static const appName = 'Worker OS';

  // common
  static const retry = 'Qayta urinish';
  static const save = 'Saqlash';
  static const cancel = 'Bekor qilish';
  static const confirm = 'Tasdiqlash';
  static const close = 'Yopish';
  static const next = 'Davom etish';
  static const loading = 'Yuklanmoqda…';
  static const optional = 'ixtiyoriy';
  static const required = 'Majburiy maydon';
  static const done = 'Tayyor';
  static const yes = 'Ha';
  static const no = "Yo'q";
  static const details = 'Batafsil';
  static const all = 'Hammasi';
  static const search = 'Qidirish';

  // network / generic errors
  static const offline = 'Internet mavjud emas.';
  static const offlineSaved = "Internet mavjud emas. Ma'lumot saqlandi va internet qaytganda yuboriladi.";
  static const serverUnavailable = "Server vaqtincha ishlamayapti. Birozdan so'ng qayta urinib ko'ring.";
  static const timeout = "Javob kelmadi. Internet sekin bo'lishi mumkin — qayta urinib ko'ring.";
  static const unknownError = "Kutilmagan xatolik yuz berdi. Qayta urinib ko'ring.";
  static const sessionExpired = 'Sessiya tugadi. Iltimos, qaytadan kiring.';

  // auth
  static const loginTitle = 'Telefon raqamingiz';
  static const loginSubtitle = 'Tasdiqlash kodi SMS orqali yuboriladi';
  static const phoneHint = '90 123 45 67';
  static const getCode = 'Kod olish';
  static const otpTitle = 'SMS koddan';
  static String otpSent(String phone) => '$phone raqamiga 6 xonali kod yuborildi';
  static const verify = 'Kirish';
  static const resend = 'Kodni qayta yuborish';
  static String resendIn(int s) => 'Qayta yuborish: $s s';
  static const changeNumber = "Raqamni o'zgartirish";
  static const invalidPhone = "Telefon raqam noto'g'ri. Masalan: 90 123 45 67";
  static const nameTitle = 'Ismingiz';
  static const nameHint = 'Ism va familiya';
  static const nameSubtitle = "Prorab va ish beruvchilar sizni shu ism bilan ko'radi";

  // onboarding
  static const welcomeTitle = 'Xush kelibsiz!';
  static const iAmWorker = 'Men ishchiman';
  static const iAmWorkerDesc = 'Ish tarixim saqlansin va yangi ish topay';
  static const iAmCompany = 'Kompaniya yarataman';
  static const iAmCompanyDesc = 'Ishchilar, obyektlar va davomatni boshqarish';
  static const waitingForCompany = "Agar prorabingiz sizni qo'shgan bo'lsa, obyekt shu yerda ko'rinadi.";
  static const createCompany = 'Kompaniya yaratish';
  static const companyName = 'Kompaniya nomi';
  static const region = 'Viloyat';
  static const city = 'Shahar / tuman';
  static const address = 'Manzil';
  static const phone = 'Telefon';
  static const description = 'Tavsif';

  // worker tabs
  static const tabToday = 'Bugun';
  static const tabJobs = 'Ishlar';
  static const tabMyWork = 'Mening ishim';
  static const tabProfile = 'Profil';

  // today
  static const startWork = 'ISHNI BOSHLASH';
  static const endWork = 'ISHNI YAKUNLASH';
  static const notStarted = 'Ish hali boshlanmagan';
  static String startedAt(String t) => 'Ish boshlandi: $t';
  static String endedAt(String t) => 'Ish yakunlandi: $t';
  static const workingNow = 'Hozir ishlayapsiz';
  static const finishedToday = 'Bugungi ish yakunlandi';
  static const noSiteTitle = 'Sizga hali obyekt biriktirilmagan';
  static const noSiteBody = "Prorabingizdan sizni Worker OS'ga qo'shishini so'rang. Shu orada ish e'lonlarini ko'rishingiz mumkin.";
  static const browseJobs = "Ish e'lonlarini ko'rish";
  static const chooseSite = 'Obyektni tanlang';
  static const gettingLocation = 'Joylashuv aniqlanmoqda…';
  static const confirmEndTitle = 'Ishni yakunlaysizmi?';
  static const confirmEndBody = 'Yakunlangandan keyin prorab ish vaqtingizni tasdiqlaydi.';
  static const residentHint = "Siz obyektda yashaysiz: ish vaqti faqat \"Boshlash\" va \"Yakunlash\" tugmalari bo'yicha hisoblanadi.";
  static const staleShift = 'Kechagi ish yakunlanmagan. Ishni boshlasangiz, u prorab tekshiruviga yuboriladi.';
  static String shiftHours(String s, String e) => 'Ish vaqti: $s – $e';
  static const pendingSync = 'Yuborilmagan';
  static String pendingCount(int n) => '$n ta amal internet kutyapti';
  static const syncing = 'Yuborilmoqda…';
  static const synced = 'Yuborildi';
  static const syncNow = 'Hozir yuborish';
  static const syncRejected = 'Qabul qilinmadi';
  static const lastUpdated = 'Oxirgi yangilanish';
  static const openTasks = 'Ochiq vazifalar';

  // location
  static const locationDisabled = "Telefoningizda joylashuv (GPS) o'chirilgan. Uni yoqing va qayta urinib ko'ring.";
  static const locationDenied = 'Joylashuvga ruxsat berilmagan. Ishni boshlash uchun ruxsat kerak.';
  static const locationDeniedForever = 'Joylashuvga ruxsat butunlay rad etilgan. Sozlamalardan ruxsat bering.';
  static const openSettings = 'Sozlamalarni ochish';
  static const locationTimeout = "Joylashuvni aniqlab bo'lmadi. Ochiq joyga chiqib qayta urinib ko'ring.";
  static String outsideSite(int meters) => "Siz obyekt hududidan tashqaridasiz (~$meters m). Obyektga yaqinroq borib qayta urinib ko'ring.";

  // my work
  static const history = 'Ish tarixi';
  static const tasks = 'Vazifalar';
  static const noHistory = "Hali ish tarixi yo'q";
  static const noHistoryBody = "Ishni boshlab-yakunlaganingizdan so'ng, prorab tasdiqlagan kunlar shu yerda ko'rinadi.";
  static const noTasks = "Vazifalar yo'q";
  static const noTasksBody = 'Prorab vazifa berganda shu yerda ko\'rinadi.';
  static const verifiedHoursTotal = 'Tasdiqlangan soatlar';
  static const dispute = "E'tiroz bildirish";
  static const disputeHint = "Nima noto'g'ri? Masalan: \"Men 18:00 gacha ishladim\"";
  static const claimedStart = 'Aslida boshlagan vaqtim';
  static const claimedEnd = 'Aslida tugatgan vaqtim';
  static const disputeSent = "E'tiroz yuborildi. Prorab ko'rib chiqadi.";
  static const timeline = 'Voqealar tarixi';
  static const startTask = 'Boshlash';
  static const submitTask = 'Tekshiruvga yuborish';
  static const addPhoto = "Rasm qo'shish";
  static const takePhoto = 'Suratga olish';
  static const fromGallery = 'Galereyadan';
  static const completedQuantity = 'Bajarilgan hajm';
  static const comment = 'Izoh';
  static const evidence = 'Dalillar (rasm)';
  static const uploadFailed = 'Rasm yuklanmadi';

  // jobs
  static const jobsTitle = "Ish e'lonlari";
  static const noJobs = "Hozircha ish e'lonlari yo'q";
  static const noJobsBody = "Keyinroq qayta tekshiring yoki filtrni o'zgartiring.";
  static const apply = 'Ariza topshirish';
  static const applied = 'Ariza yuborildi';
  static const withdraw = 'Arizani qaytarib olish';
  static const coverNote = 'Qisqa xabar (tajribangiz, qachon boshlay olasiz)';
  static const myApplications = 'Mening arizalarim';
  static const noApplications = "Hali ariza yo'q";
  static const requirements = 'Talablar';
  static const workersNeeded = 'Kerakli ishchilar';
  static const startDate = 'Boshlanish sanasi';
  static const duration = 'Davomiyligi';
  static const companyTrust = 'Kompaniya haqida';
  static const verifiedCompany = 'Tasdiqlangan kompaniya';
  static const notVerifiedCompany = 'Kompaniya hali tasdiqlanmagan';
  static const workersManaged = 'Boshqarilgan ishchilar';
  static const verifiedShifts = 'Tasdiqlangan ish kunlari';
  static const completedVacancies = 'Yopilgan vakansiyalar';
  static const memberSince = "Worker OS'da";

  // profile / identity
  static const verifiedWork = 'Tasdiqlangan ish tarixi';
  static const selfReported = "O'zingiz kiritgan ma'lumot";
  static const verifiedWorkdays = 'Ish kunlari';
  static const verifiedHours = 'Soat';
  static const verifiedTasks = 'Vazifalar';
  static const employers = 'Ish beruvchilar';
  static const attendance = 'Davomat';
  static const punctuality = "O'z vaqtida";
  static const trustLevel = 'Ishonch darajasi';
  static const experienceYears = 'Tajriba (yil)';
  static const trade = 'Kasb';
  static const bio = "O'zim haqimda";
  static const editProfile = 'Profilni tahrirlash';
  static const notifications = 'Bildirishnomalar';
  static const noNotifications = "Bildirishnomalar yo'q";
  static const readAll = "Hammasini o'qilgan deb belgilash";
  static const settings = 'Sozlamalar';
  static const logout = 'Chiqish';
  static const logoutConfirm = 'Hisobdan chiqasizmi?';
  static const logoutPending = "Yuborilmagan amallar bor. Chiqsangiz, ular yo'qoladi. Avval internetga ulaning.";
  static const sessions = 'Qurilmalar';
  static const switchContext = 'Rolni almashtirish';
  static const workerMode = 'Ishchi rejimi';
  static const leaveCompany = 'Kompaniyadan chiqish';

  // company
  static const tabDashboard = 'Bugun';
  static const tabWorkers = 'Ishchilar';
  static const tabShifts = 'Tasdiqlash';
  static const tabMore = "Ko'proq";
  static const assigned = 'Biriktirilgan';
  static const present = 'Kelgan';
  static const late = 'Kechikkan';
  static const absent = 'Kelmagan';
  static const notYet = 'Hali kelmagan';
  static const onSite = 'Obyektda';
  static const checkedOut = 'Ketgan';
  static const pendingCheckout = 'Yakunlamagan';
  static const dayOff = 'Dam olish';
  static const awaitingVerification = 'Tasdiqlash kutilmoqda';
  static const openDisputes = "E'tirozlar";
  static const tasksAwaitingReview = 'Tekshiriladigan vazifalar';
  static const noWorkers = "Hali ishchilar yo'q";
  static const addFirstWorker = "Birinchi ishchingizni qo'shing";
  static const addWorker = "Ishchi qo'shish";
  static const addForeman = "Prorab qo'shish";
  static const fullName = 'F.I.Sh.';
  static const position = 'Lavozim / kasb';
  static const sites = 'Obyektlar';
  static const residentWorker = 'Obyektda yashaydi';
  static const residentWorkerDesc = "GPS emas, faqat Boshlash/Yakunlash va prorab tasdig'i hisoblanadi";
  static const noSites = "Hali obyektlar yo'q";
  static const createFirstSite = 'Birinchi loyiha va obyektni yarating';
  static const createProject = 'Loyiha yaratish';
  static const createSite = 'Obyekt yaratish';
  static const projectName = 'Loyiha nomi';
  static const siteName = 'Obyekt nomi';
  static const radius = 'Hudud radiusi (m)';
  static const shiftStart = 'Ish boshlanishi';
  static const shiftEnd = 'Ish tugashi';
  static const useCurrentLocation = 'Hozirgi joylashuvimni olish (obyektda turib bosing)';
  static const latitude = 'Kenglik (lat)';
  static const longitude = 'Uzunlik (lng)';
  static const nothingToVerify = "Tasdiqlanadigan smenalar yo'q";
  static const nothingToVerifyBody = "Ishchilar ishni yakunlaganda smenalar shu yerda paydo bo'ladi.";
  static const verifyAll = 'Hammasini tasdiqlash';
  static const verifySelected = 'Tanlanganlarni tasdiqlash';
  static const verifyShift = 'Tasdiqlash';
  static const rejectShift = 'Rad etish';
  static const correctShift = "Vaqtni to'g'rilash";
  static const reason = 'Sabab';
  static const breakMinutes = 'Tanaffus (daqiqa)';
  static const manualAttendance = 'Qo\'lda belgilash (telefoni yo\'q ishchi)';
  static const flags = 'Belgilar';
  static const createTask = 'Vazifa berish';
  static const taskTitle = 'Vazifa';
  static const quantity = 'Hajm';
  static const unit = 'Birlik';
  static const dueDate = 'Muddat';
  static const approve = 'Tasdiqlash';
  static const reject = 'Rad etish';
  static const requestChanges = "Qayta ishlashni so'rash";
  static const vacancies = 'Vakansiyalar';
  static const createVacancy = 'Vakansiya yaratish';
  static const noVacancies = "Vakansiyalar yo'q";
  static const createFirstVacancy = 'Birinchi vakansiyani yarating';
  static const applications = 'Arizalar';
  static const noApplicants = "Hali arizalar yo'q";
  static const shortlist = 'Saralash';
  static const accept = 'Ishga olish';
  static const publish = "E'lon qilish";
  static const pause = "To'xtatish";
  static const closeVacancy = 'Yopish';
  static const rate = "To'lov";
  static const category = 'Kasb turi';
  static const paymentPeriod = "To'lov davri";
  static const disputes = "E'tirozlar";
  static const noDisputes = "E'tirozlar yo'q";
  static const acceptDispute = 'Qabul qilish';
  static const rejectDispute = 'Rad etish';
  static const companyProfile = 'Kompaniya profili';
  static const requestVerification = "Tasdiqlashga so'rov yuborish";
  static const stir = 'STIR (9 raqam)';
  static const projects = 'Loyihalar';
  static const auditLog = 'Audit jurnali';
}

/// Maps stable API error codes to specific, actionable Uzbek messages.
String messageForCode(String code, {Map<String, dynamic>? details, String? fallback}) {
  switch (code) {
    case 'INVALID_PHONE':
      return S.invalidPhone;
    case 'OTP_COOLDOWN':
      final s = details?['retryAfterSeconds'];
      return "Kodni qayta so'rashdan oldin ${s ?? 60} soniya kuting.";
    case 'OTP_LIMIT_EXCEEDED':
      return "Juda ko'p kod so'raldi. 1 soatdan keyin urinib ko'ring.";
    case 'OTP_INVALID':
      final left = details?['attemptsLeft'];
      return left != null ? "Kod noto'g'ri. Yana $left ta urinish qoldi." : "Kod noto'g'ri.";
    case 'OTP_EXPIRED':
      return "Kod eskirgan. Yangi kod so'rang.";
    case 'OTP_TOO_MANY_ATTEMPTS':
      return "Ko'p marta noto'g'ri kiritildi. Yangi kod so'rang.";
    case 'SMS_SEND_FAILED':
      return "SMS yuborib bo'lmadi. Birozdan so'ng qayta urinib ko'ring.";
    case 'USER_DEACTIVATED':
      return "Hisobingiz bloklangan. Administrator bilan bog'laning.";
    case 'SESSION_REVOKED':
    case 'REFRESH_INVALID':
    case 'TOKEN_EXPIRED':
      return S.sessionExpired;
    case 'RATE_LIMITED':
      return "Juda ko'p so'rov. Bir daqiqadan so'ng qayta urinib ko'ring.";
    case 'NOT_ASSIGNED_TO_SITE':
      return 'Siz bu obyektga biriktirilmagansiz. Prorabingizga murojaat qiling.';
    case 'SITE_INACTIVE':
      return 'Bu obyekt hozir faol emas.';
    case 'MEMBERSHIP_INACTIVE':
      return "Kompaniyadagi a'zoligingiz to'xtatilgan. Prorabingizga murojaat qiling.";
    case 'ALREADY_CHECKED_IN':
      return 'Siz ishni allaqachon boshlagansiz.';
    case 'NO_OPEN_SHIFT':
      return 'Siz hali ishni boshlamagansiz.';
    case 'OUTSIDE_GEOFENCE':
      final d = details?['distanceMeters'];
      return d is num ? S.outsideSite(d.round()) : 'Siz obyekt hududidan tashqaridasiz.';
    case 'LOCATION_REQUIRED':
      return 'Ishni boshlash uchun joylashuv kerak. GPS ni yoqing.';
    case 'TIMESTAMP_IN_FUTURE':
      return "Telefoningiz soati noto'g'ri. Sana va vaqtni avtomatik qilib qo'ying.";
    case 'EVENT_TOO_OLD':
      return "Bu amal juda eski (3 kundan ortiq). Prorabingiz uni qo'lda kiritishi kerak.";
    case 'END_BEFORE_START':
      return "Tugash vaqti boshlanish vaqtidan oldin bo'lishi mumkin emas.";
    case 'SHIFT_NOT_REVIEWABLE':
      return "Bu smenani hozir tasdiqlab bo'lmaydi. Avval vaqtni to'g'rilang.";
    case 'SHIFT_OPEN':
      return 'Ishchining ochiq smenasi bor. Avval uni yakunlang.';
    case 'CANNOT_REVIEW_OWN_WORK':
      return "O'z ishingizni o'zingiz tasdiqlay olmaysiz.";
    case 'NOT_A_MEMBER':
    case 'ROLE_NOT_ALLOWED':
      return "Bu amal uchun sizda ruxsat yo'q.";
    case 'SITE_NOT_ASSIGNED':
      return 'Bu obyekt sizga biriktirilmagan.';
    case 'WORKER_NOT_IN_YOUR_SITES':
      return 'Bu ishchi sizga biriktirilmagan.';
    case 'MEMBER_ALREADY_EXISTS':
      return 'Bu odam allaqachon kompaniyada.';
    case 'CANNOT_MODIFY_SELF':
      return "O'z rolingizni o'zgartira olmaysiz.";
    case 'LAST_ADMIN':
      return 'Kompaniyada kamida bitta administrator qolishi kerak.';
    case 'TASK_INVALID_STATE':
      return "Vazifa holati o'zgargan. Sahifani yangilang.";
    case 'FILE_REQUIRED':
      return 'Rasm tanlang.';
    case 'FILE_TOO_LARGE':
      return 'Fayl juda katta (maksimum 8 MB).';
    case 'FILE_TYPE_NOT_ALLOWED':
      return 'Faqat JPG, PNG, WEBP rasm yoki PDF yuklash mumkin.';
    case 'STORAGE_UNAVAILABLE':
      return "Fayl saqlash xizmati vaqtincha ishlamayapti. Keyinroq urinib ko'ring.";
    case 'VACANCY_NOT_OPEN':
      return 'Bu vakansiya ariza qabul qilmayapti.';
    case 'ALREADY_APPLIED':
      return 'Siz bu vakansiyaga ariza topshirgansiz.';
    case 'ALREADY_MEMBER':
      return 'Siz allaqachon shu kompaniyada ishlaysiz.';
    case 'BLOCKED_BY_COMPANY':
      return 'Bu kompaniyaga ariza topshira olmaysiz.';
    case 'APPLICATION_INVALID_STATE':
      return "Ariza holati o'zgargan. Sahifani yangilang.";
    case 'DISPUTE_ALREADY_OPEN':
      return "Bu smena bo'yicha e'tiroz allaqachon yuborilgan.";
    case 'DISPUTE_NOT_OPEN':
      return "E'tiroz allaqachon ko'rib chiqilgan.";
    case 'NOT_FOUND':
      return "Ma'lumot topilmadi yoki o'chirilgan.";
    case 'FORBIDDEN':
      return "Bu ma'lumotni ko'rishga ruxsat yo'q.";
    case 'VALIDATION_FAILED':
      return "Kiritilgan ma'lumotlarni tekshiring.";
    case 'CONFLICT':
      return fallback ?? "Ma'lumot allaqachon mavjud.";
    case 'INTERNAL':
      return S.serverUnavailable;
  }
  return fallback ?? S.unknownError;
}
