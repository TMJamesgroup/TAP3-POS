import test from 'node:test';
import assert from 'node:assert/strict';
import {requireManager,requireCashier,denominationTotal,validateDrawerOpen,validateMovement,expectedCash} from './cash-controls.js';
const staff={authenticated:true,active:true,staffId:'staff-1',restaurantId:'restaurant-1',role:'bartender'};
test('server-derived staff scope blocks wrong restaurant',()=>{
  assert.throws(()=>requireCashier(staff,'restaurant-2'),/Forbidden/);
  assert.equal(requireCashier(staff,'restaurant-1'),'staff-1');
  assert.throws(()=>requireManager(staff,'restaurant-1'),/Forbidden/);
});
test('manager authorization requires active authenticated manager',()=>{
  assert.equal(requireManager({...staff,role:'manager'},'restaurant-1'),'staff-1');
  assert.throws(()=>requireManager({...staff,role:'manager',active:false},'restaurant-1'),/Forbidden/);
});
test('denomination counts use integer cents and reject invalid counts',()=>{
  assert.equal(denominationTotal({'10000':2,'5000':1}),25000);
  assert.throws(()=>denominationTotal({'10000':-1}),/Invalid/);
  assert.throws(()=>denominationTotal({'3':1}),/Invalid/);
});
test('drawer opening requires approved reason and notes for other',()=>{
  assert.equal(validateDrawerOpen('making_change').reason,'making_change');
  assert.throws(()=>validateDrawerOpen('other'),/reason/);
});
test('cash movements and ledger totals reject malformed values',()=>{
  assert.equal(validateMovement('cash_sale',100).amountCents,100);
  assert.throws(()=>validateMovement('cash_sale',1.25),/Invalid/);
  assert.equal(expectedCash(10000,[2000,-500]),11500);
});
