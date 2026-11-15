"""TAP3 receipt printer / cash drawer simulator (no hardware required).

Run: python -m unittest discover -s printer-connector -p 'test_*.py'
This simulator NEVER sends commands to real printers or opens real drawers.
"""
from dataclasses import dataclass, field
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from threading import RLock
from uuid import uuid4

DENOMINATIONS = (10000, 5000, 2000, 1000, 500, 100, 25, 10, 5, 1)

def cents(value):
    try:
        d = Decimal(str(value))
    except (InvalidOperation, ValueError):
        raise ValueError("Invalid monetary amount")
    if not d.is_finite() or d != d.to_integral_value():
        raise ValueError("Amount must be integer cents")
    return int(d)

@dataclass
class Drawer:
    id: str
    opening_bank_cents: int
    expected_cents: int = 0
    assigned_employee: str | None = None
    open_shift: bool = False
    events: list = field(default_factory=list)

class CashDrawerSimulator:
    """In-memory test fixture. Never use for production cash accounting."""
    def __init__(self):
        self.drawers = {}
        self.lock = RLock()

    def _event(self, drawer, kind, actor, **details):
        entry = dict(id=str(uuid4()), timestamp=datetime.now(timezone.utc).isoformat(),
                     drawer_id=drawer.id, kind=kind, actor=actor, **details)
        drawer.events.append(entry)
        return entry

    def configure(self, drawer_id, bank_cents, manager, reason):
        if not manager or not reason:
            raise ValueError("Manager and reason required")
        amount = cents(bank_cents)
        if amount < 0:
            raise ValueError("Bank cannot be negative")
        with self.lock:
            d = self.drawers.get(drawer_id)
            if d is None:
                d = Drawer(drawer_id, amount)
                self.drawers[drawer_id] = d
            else:
                if d.open_shift:
                    raise ValueError("Cannot change bank during open shift")
                d.opening_bank_cents = amount
            self._event(d, "configure_bank", manager, bank_cents=amount, reason=reason)
            return d

    @staticmethod
    def count_total(denominations):
        if not isinstance(denominations, dict):
            raise ValueError("Denomination count required")
        total = 0
        for denomination, quantity in denominations.items():
            if type(denomination) is not int or denomination not in DENOMINATIONS:
                raise ValueError("Unsupported denomination")
            if type(quantity) is not int or quantity < 0:
                raise ValueError("Counts must be nonnegative integers")
            total += denomination * quantity
        return total

    def start_shift(self, drawer_id, employee, denominations):
        with self.lock:
            d = self.drawers[drawer_id]
            if not employee or d.open_shift:
                raise ValueError("Employee required and drawer must be unassigned")
            actual = self.count_total(denominations)
            if actual != d.opening_bank_cents:
                self._event(d, "opening_variance", employee, counted_cents=actual,
                            expected_cents=d.opening_bank_cents)
                raise ValueError("Opening count variance requires manager resolution")
            d.open_shift = True
            d.assigned_employee = employee
            d.expected_cents = actual
            return self._event(d, "shift_start", employee, counted_cents=actual)

    def open_drawer(self, drawer_id, employee, reason, notes=""):
        with self.lock:
            d = self.drawers[drawer_id]
            allowed = bool(d.open_shift and employee == d.assigned_employee and reason)
            event = self._event(d, "open_request", employee, reason=reason,
                                notes=notes, allowed=allowed, simulated=True)
            if not allowed:
                raise PermissionError("Drawer open denied; attempt logged")
            return event

    def movement(self, drawer_id, employee, kind, amount_cents, reason):
        if kind not in ("cash_sale", "cash_refund", "paid_in", "paid_out", "safe_drop"):
            raise ValueError("Unsupported cash movement")
        amount = cents(amount_cents)
        if amount <= 0 or not reason:
            raise ValueError("Positive amount and reason required")
        with self.lock:
            d = self.drawers[drawer_id]
            if not d.open_shift or employee != d.assigned_employee:
                raise PermissionError("Drawer not assigned to employee")
            delta = amount if kind in ("cash_sale", "paid_in") else -amount
            d.expected_cents += delta
            return self._event(d, kind, employee, amount_cents=amount,
                               expected_cents=d.expected_cents, reason=reason)

    def blind_count(self, drawer_id, manager, denominations):
        if not manager:
            raise ValueError("Manager required")
        counted = self.count_total(denominations)
        with self.lock:
            d = self.drawers[drawer_id]
            # No expected balance is returned before the count is submitted.
            return self._event(d, "blind_count", manager, counted_cents=counted,
                               expected_cents=d.expected_cents,
                               variance_cents=counted - d.expected_cents)

    def close_shift(self, drawer_id, employee, denominations):
        counted = self.count_total(denominations)
        with self.lock:
            d = self.drawers[drawer_id]
            if not d.open_shift or employee != d.assigned_employee:
                raise PermissionError("Not assigned")
            if counted != d.expected_cents:
                self._event(d, "closing_variance", employee, counted_cents=counted,
                            expected_cents=d.expected_cents)
                raise ValueError("Closing variance requires manager resolution")
            event = self._event(d, "shift_close", employee, counted_cents=counted)
            d.open_shift = False
            d.assigned_employee = None
            return event

    def receipt(self, items, total_cents):
        amount = cents(total_cents)
        if amount < 0:
            raise ValueError("Invalid total")
        return dict(mode="SIMULATED", job_id=str(uuid4()), items=list(items),
                    total_cents=amount, printed=False, hardware_command_sent=False)
