import fs from 'node:fs';
import pg from 'pg';
import {randomUUID} from 'node:crypto';

const catalog=JSON.parse(fs.readFileSync(new URL('../data/tap2-menu.json',import.meta.url),'utf8'));
const restaurantId=process.env.TAP2_RESTAURANT_ID;
const apply=process.argv.includes('--apply');
const eligible=catalog.items.filter(i=>i.status==='confirmed' && Number.isInteger(i.price_cents));
const pending=catalog.items.filter(i=>i.status!=='confirmed');
const displayName=i=>i.variant?`${i.name} — ${i.variant}`:i.name;
console.log(JSON.stringify({restaurant:catalog.restaurant,total:catalog.items.length,ready:eligible.length,not_for_sale:pending.length,mode:apply?'apply':'preview',pending:pending.map(i=>displayName(i))},null,2));
if(!apply)process.exit(0);
if(!restaurantId||!process.env.DATABASE_URL)throw Error('TAP2_RESTAURANT_ID and DATABASE_URL required; no writes performed');
if(!/^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(restaurantId))throw Error('Invalid restaurant UUID');
const pool=new pg.Pool({connectionString:process.env.DATABASE_URL,ssl:process.env.PGSSLMODE==='disable'?false:{rejectUnauthorized:true}});
const client=await pool.connect();
try{
 await client.query('BEGIN');
 const restaurant=await client.query('SELECT id,name FROM restaurants WHERE id=$1 FOR UPDATE',[restaurantId]);
 if(restaurant.rowCount!==1||!/^TAP\s*2\.0\b/i.test(restaurant.rows[0].name))throw Error('Restaurant does not exist or is not TAP 2.0; rollback');
 for(const item of eligible){
  const name=displayName(item);
  const found=await client.query('SELECT id FROM menu_items WHERE restaurant_id=$1 AND name=$2 FOR UPDATE',[restaurantId,name]);
  if(found.rowCount>1)throw Error('Duplicate existing menu item: '+name);
  if(found.rowCount===1)await client.query('UPDATE menu_items SET category=$1,price_cents=$2,active=true WHERE id=$3',[item.category,item.price_cents,found.rows[0].id]);
  else await client.query('INSERT INTO menu_items(id,restaurant_id,name,category,price_cents,active) VALUES($1,$2,$3,$4,$5,true)',[randomUUID(),restaurantId,name,item.category,item.price_cents]);
 }
 await client.query('COMMIT');
 console.log('Imported '+eligible.length+' priced menu entries; pending prices were not activated.');
}catch(e){await client.query('ROLLBACK');throw e}finally{client.release();await pool.end()}
