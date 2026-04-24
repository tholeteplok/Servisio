/**
 * Firestore Security Rules Test — Servisio Core
 * 
 * Menguji semua subcollection di bengkel/{bengkelId} dengan skenario:
 * - owner: harus bisa semua operasi
 * - staff dengan permission: harus bisa operasi yang diizinkan
 * - staff tanpa permission: harus ditolak
 * - unauthenticated: harus ditolak semua
 */

const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, addDoc } = require('firebase/firestore');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'servislog-plus';
const BENGKEL_ID = 'bengkel-test-001';
const OWNER_UID = 'owner-uid-001';
const STAFF_UID = 'staff-uid-001';
const OTHER_UID = 'other-uid-999';

let testEnv;

// ── Helper: buat auth context ──────────────────────────────────────────────

function ownerAuth() {
  return { uid: OWNER_UID, token: { bengkelId: BENGKEL_ID, role: 'owner' } };
}

function staffAuth(customPermissions = {}) {
  return { uid: STAFF_UID, token: { bengkelId: BENGKEL_ID, role: 'staff' } };
}

function otherBengkelAuth() {
  return { uid: OTHER_UID, token: { bengkelId: 'bengkel-lain', role: 'owner' } };
}

// ── Setup & Teardown ───────────────────────────────────────────────────────

async function setup() {
  const rulesContent = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: rulesContent,
      host: '127.0.0.1',
      port: 8080,
    },
  });

  // Seed: buat dokumen staff dengan customPermissions
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    // Staff dengan permission transaksi_create dan pelanggan_create
    await setDoc(doc(db, `bengkel/${BENGKEL_ID}/staff/${STAFF_UID}`), {
      uuid: STAFF_UID,
      name: 'Test Staff',
      role: 'staff',
      customPermissions: {
        transaksi_create: true,
        transaksi_update: true,
        pelanggan_create: true,
        pelanggan_update: true,
        stok_create: true,
        stok_update_jumlah: true,
      },
    });

    // Dokumen transaksi untuk test read/update/delete
    await setDoc(doc(db, `bengkel/${BENGKEL_ID}/transactions/trx-001`), {
      uuid: 'trx-001',
      bengkelId: BENGKEL_ID,
      customerName: 'Test Customer',
      isDeleted: false,
    });

    // Dokumen customer
    await setDoc(doc(db, `bengkel/${BENGKEL_ID}/customers/cust-001`), {
      uuid: 'cust-001',
      name: 'Test Pelanggan',
    });

    // Dokumen inventory
    await setDoc(doc(db, `bengkel/${BENGKEL_ID}/inventory/inv-001`), {
      uuid: 'inv-001',
      nama: 'Oli Mesin',
      jumlah: 10,
    });

    // Dokumen security_audit_logs
    await setDoc(doc(db, `bengkel/${BENGKEL_ID}/security_audit_logs/log-001`), {
      action: 'login',
      timestamp: new Date(),
    });
  });

  console.log('✅ Setup selesai — data seed berhasil\n');
}

async function teardown() {
  await testEnv.cleanup();
}

// ── Test Runner ────────────────────────────────────────────────────────────

let passed = 0;
let failed = 0;

async function test(name, fn) {
  try {
    await fn();
    console.log(`  ✅ ${name}`);
    passed++;
  } catch (e) {
    console.log(`  ❌ ${name}`);
    console.log(`     ${e.message}`);
    failed++;
  }
}

// ── TEST SUITES ────────────────────────────────────────────────────────────

async function testTransactions() {
  console.log('\n📋 TRANSACTIONS');

  const ownerDb = testEnv.authenticatedContext(OWNER_UID, ownerAuth().token).firestore();
  const staffDb = testEnv.authenticatedContext(STAFF_UID, staffAuth().token).firestore();
  const unauthDb = testEnv.unauthenticatedContext().firestore();
  const otherDb = testEnv.authenticatedContext(OTHER_UID, otherBengkelAuth().token).firestore();

  const trxRef = doc(ownerDb, `bengkel/${BENGKEL_ID}/transactions/trx-001`);
  const newTrxRef = doc(ownerDb, `bengkel/${BENGKEL_ID}/transactions/trx-new`);

  await test('owner bisa read transaksi', () =>
    assertSucceeds(getDoc(doc(ownerDb, `bengkel/${BENGKEL_ID}/transactions/trx-001`)))
  );

  await test('owner bisa create transaksi', () =>
    assertSucceeds(setDoc(doc(ownerDb, `bengkel/${BENGKEL_ID}/transactions/trx-owner-new`), {
      uuid: 'trx-owner-new', bengkelId: BENGKEL_ID, customerName: 'X', isDeleted: false,
    }))
  );

  await test('owner bisa delete transaksi', () =>
    assertSucceeds(deleteDoc(doc(ownerDb, `bengkel/${BENGKEL_ID}/transactions/trx-owner-new`)))
  );

  await test('staff dengan transaksi_create bisa create', () =>
    assertSucceeds(setDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/transactions/trx-staff-new`), {
      uuid: 'trx-staff-new', bengkelId: BENGKEL_ID, customerName: 'Y', isDeleted: false,
    }))
  );

  await test('staff dengan transaksi_update bisa update', () =>
    assertSucceeds(updateDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/transactions/trx-001`), {
      customerName: 'Updated',
    }))
  );

  await test('staff TIDAK bisa delete transaksi', () =>
    assertFails(deleteDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/transactions/trx-001`)))
  );

  await test('unauthenticated TIDAK bisa read transaksi', () =>
    assertFails(getDoc(doc(unauthDb, `bengkel/${BENGKEL_ID}/transactions/trx-001`)))
  );

  await test('user bengkel lain TIDAK bisa read transaksi', () =>
    assertFails(getDoc(doc(otherDb, `bengkel/${BENGKEL_ID}/transactions/trx-001`)))
  );
}

async function testCustomers() {
  console.log('\n👥 CUSTOMERS');

  const ownerDb = testEnv.authenticatedContext(OWNER_UID, ownerAuth().token).firestore();
  const staffDb = testEnv.authenticatedContext(STAFF_UID, staffAuth().token).firestore();
  const unauthDb = testEnv.unauthenticatedContext().firestore();

  await test('owner bisa read customers', () =>
    assertSucceeds(getDoc(doc(ownerDb, `bengkel/${BENGKEL_ID}/customers/cust-001`)))
  );

  await test('staff dengan pelanggan_create bisa create customer', () =>
    assertSucceeds(setDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/customers/cust-staff-new`), {
      uuid: 'cust-staff-new', name: 'Pelanggan Baru',
    }))
  );

  await test('staff dengan pelanggan_update bisa update customer', () =>
    assertSucceeds(updateDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/customers/cust-001`), {
      name: 'Updated Name',
    }))
  );

  await test('staff TIDAK bisa delete customer', () =>
    assertFails(deleteDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/customers/cust-001`)))
  );

  await test('unauthenticated TIDAK bisa read customers', () =>
    assertFails(getDoc(doc(unauthDb, `bengkel/${BENGKEL_ID}/customers/cust-001`)))
  );
}

async function testInventory() {
  console.log('\n📦 INVENTORY');

  const ownerDb = testEnv.authenticatedContext(OWNER_UID, ownerAuth().token).firestore();
  const staffDb = testEnv.authenticatedContext(STAFF_UID, staffAuth().token).firestore();

  await test('owner bisa read inventory', () =>
    assertSucceeds(getDoc(doc(ownerDb, `bengkel/${BENGKEL_ID}/inventory/inv-001`)))
  );

  await test('staff dengan stok_create bisa create inventory', () =>
    assertSucceeds(setDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/inventory/inv-staff-new`), {
      uuid: 'inv-staff-new', nama: 'Filter Oli', jumlah: 5,
    }))
  );

  await test('staff dengan stok_update_jumlah bisa update inventory', () =>
    assertSucceeds(updateDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/inventory/inv-001`), {
      jumlah: 8,
    }))
  );

  await test('staff TIDAK bisa delete inventory', () =>
    assertFails(deleteDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/inventory/inv-001`)))
  );
}

async function testSecurityAuditLogs() {
  console.log('\n🔒 SECURITY AUDIT LOGS');

  const ownerDb = testEnv.authenticatedContext(OWNER_UID, ownerAuth().token).firestore();
  const staffDb = testEnv.authenticatedContext(STAFF_UID, staffAuth().token).firestore();
  const unauthDb = testEnv.unauthenticatedContext().firestore();

  await test('owner BISA read security_audit_logs', () =>
    assertSucceeds(getDoc(doc(ownerDb, `bengkel/${BENGKEL_ID}/security_audit_logs/log-001`)))
  );

  await test('staff TIDAK bisa read security_audit_logs', () =>
    assertFails(getDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/security_audit_logs/log-001`)))
  );

  await test('owner TIDAK bisa write security_audit_logs (Cloud Functions only)', () =>
    assertFails(setDoc(doc(ownerDb, `bengkel/${BENGKEL_ID}/security_audit_logs/log-new`), {
      action: 'test',
    }))
  );

  await test('staff TIDAK bisa write security_audit_logs', () =>
    assertFails(setDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/security_audit_logs/log-new`), {
      action: 'test',
    }))
  );

  await test('unauthenticated TIDAK bisa read security_audit_logs', () =>
    assertFails(getDoc(doc(unauthDb, `bengkel/${BENGKEL_ID}/security_audit_logs/log-001`)))
  );
}

async function testOperations() {
  console.log('\n⚙️  _OPERATIONS (idempotency keys)');

  const ownerDb = testEnv.authenticatedContext(OWNER_UID, ownerAuth().token).firestore();
  const staffDb = testEnv.authenticatedContext(STAFF_UID, staffAuth().token).firestore();
  const unauthDb = testEnv.unauthenticatedContext().firestore();

  await test('owner bisa write _operations', () =>
    assertSucceeds(setDoc(doc(ownerDb, `bengkel/${BENGKEL_ID}/_operations/op-001`), {
      status: 'completed',
    }))
  );

  await test('staff bisa write _operations (dibutuhkan untuk sync)', () =>
    assertSucceeds(setDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/_operations/op-staff-001`), {
      status: 'completed',
    }))
  );

  await test('unauthenticated TIDAK bisa write _operations', () =>
    assertFails(setDoc(doc(unauthDb, `bengkel/${BENGKEL_ID}/_operations/op-unauth`), {
      status: 'completed',
    }))
  );
}

async function testWildcardFallback() {
  console.log('\n🚫 WILDCARD FALLBACK (subcollection tidak terdaftar)');

  const ownerDb = testEnv.authenticatedContext(OWNER_UID, ownerAuth().token).firestore();
  const staffDb = testEnv.authenticatedContext(STAFF_UID, staffAuth().token).firestore();

  await test('owner TIDAK bisa read subcollection tidak dikenal', () =>
    assertFails(getDoc(doc(ownerDb, `bengkel/${BENGKEL_ID}/unknown_collection/doc-001`)))
  );

  await test('owner TIDAK bisa write subcollection tidak dikenal', () =>
    assertFails(setDoc(doc(ownerDb, `bengkel/${BENGKEL_ID}/unknown_collection/doc-001`), {
      data: 'test',
    }))
  );

  await test('staff TIDAK bisa read subcollection tidak dikenal', () =>
    assertFails(getDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/unknown_collection/doc-001`)))
  );
}

async function testInternal() {
  console.log('\n🔧 _INTERNAL (migration status)');

  const ownerDb = testEnv.authenticatedContext(OWNER_UID, ownerAuth().token).firestore();
  const staffDb = testEnv.authenticatedContext(STAFF_UID, staffAuth().token).firestore();

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `bengkel/${BENGKEL_ID}/_internal/migration_status`), {
      fullyCompleted: false,
    });
  });

  await test('owner bisa read _internal', () =>
    assertSucceeds(getDoc(doc(ownerDb, `bengkel/${BENGKEL_ID}/_internal/migration_status`)))
  );

  await test('staff bisa read _internal', () =>
    assertSucceeds(getDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/_internal/migration_status`)))
  );

  await test('owner bisa write _internal', () =>
    assertSucceeds(updateDoc(doc(ownerDb, `bengkel/${BENGKEL_ID}/_internal/migration_status`), {
      fullyCompleted: true,
    }))
  );

  await test('staff TIDAK bisa write _internal', () =>
    assertFails(updateDoc(doc(staffDb, `bengkel/${BENGKEL_ID}/_internal/migration_status`), {
      fullyCompleted: true,
    }))
  );
}

// ── MAIN ───────────────────────────────────────────────────────────────────

async function main() {
  console.log('🔥 Firestore Rules Test — Servisio Core');
  console.log('=========================================');

  await setup();

  await testTransactions();
  await testCustomers();
  await testInventory();
  await testSecurityAuditLogs();
  await testOperations();
  await testWildcardFallback();
  await testInternal();

  await teardown();

  console.log('\n=========================================');
  console.log(`Hasil: ${passed} passed, ${failed} failed`);

  if (failed > 0) {
    process.exit(1);
  }
}

main().catch((e) => {
  console.error('Fatal error:', e);
  process.exit(1);
});
