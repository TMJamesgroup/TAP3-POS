// TAP3 cash controls — pure server-side validation helpers.
// Not wired to live routes. Never trust a browser-supplied role or staff identity.
export const MANAGER_ROLES = new Set(['owner', 'manager']);
export const CASH_ROLES = new Set(['owner', 'manager', 'bartender', 'server']);
export const REASONS = new Set([
  'making_change','customer_request','safe_drop','cash_added',
  'manager_count','shift_transfer','other'
]);
export const MOVEMENTS = new Set(['cash_sale','cash_refund','paid_in','paid_out','safe_drop']);
export const DENOMINATIONS = [10000,5000,2000,1000,500,100,25,10,5,1];

export function requireStaff(session, restaurantId, allowedRoles) {
  if (!session || session.authenticated !== true || session.active !== true ||
      !session.staffId || !session.restaurantId ||
      session.restaurantId !== restaurantId || !allowedRoles.has(session.role)) {
    throw Object.assign(new Error('Forbidden'), {status:403});
  }
  return session.staffId;
}

export function requireManager(session, restaurantId) {
  return requireStaff(session, restaurantId, MANAGER_ROLES);
}

export function requireCashier(session, restaurantId) {
  return requireStaff(session, restaurantId, CASH_ROLES);
}

export function validateAmountCents(value, {allowZero=false}={}) {
  if (!Number.isSafeInteger(value) || value < 0 || (!allowZero && value === 0))
    throw Object.assign(new Error('Invalid amount in integer cents'), {status:400});
  return value;
}

export function denominationTotal(counts) {
  if (!counts || typeof counts !== 'object' || Array.isArray(counts) ||
      Object.keys(counts).some(key => !DENOMINATIONS.includes(Number(key))))
    throw Object.assign(new Error('Invalid denominations'), {status:400});
  let total=0;
  for (const denom of DENOMINATIONS) {
    const quantity=counts[String(denom)] ?? 0;
    if (!Number.isSafeInteger(quantity) || quantity < 0)
      throw Object.assign(new Error('Invalid denomination quantity'), {status:400});
    total+=denom*quantity;
    if (!Number.isSafeInteger(total))
      throw Object.assign(new Error('Count exceeds supported range'), {status:400});
  }
  return total;
}

export function validateDrawerOpen(reason, notes='') {
  if (!REASONS.has(reason) || typeof notes !== 'string' || notes.length > 500 ||
      (reason === 'other' && !notes.trim()))
    throw Object.assign(new Error('Valid reason and notes required'), {status:400});
  return {reason, notes:notes.trim()};
}

export function validateMovement(kind, amountCents) {
  if (!MOVEMENTS.has(kind))
    throw Object.assign(new Error('Invalid cash movement'), {status:400});
  return {kind, amountCents:validateAmountCents(amountCents)};
}

// Expected cash is derived from the ledger, never trusted from client input.
export function expectedCash(openingCents, deltas) {
  let total=validateAmountCents(openingCents,{allowZero:true});
  for (const delta of deltas) {
    if (!Number.isSafeInteger(delta)) throw new Error('Invalid ledger delta');
    total+=delta;
    if (!Number.isSafeInteger(total)) throw new Error('Ledger overflow');
  }
  return total;
}
