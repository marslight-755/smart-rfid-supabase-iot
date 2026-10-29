-- Atomic warehouse operations. These functions are called by the authenticated dashboard.
alter table public.products add column if not exists on_hand integer not null default 0;
create or replace function public.assert_org_member(target_org uuid) returns void language plpgsql security definer set search_path=public as $$
begin if not exists(select 1 from organization_members where organization_id=target_org and user_id=auth.uid()) then raise exception 'Not authorized for organization'; end if; end; $$;

create or replace function public.receive_stock(p_org uuid,p_product uuid,p_quantity integer,p_to_location uuid,p_reference text default '') returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin perform assert_org_member(p_org); if p_quantity<=0 then raise exception 'Quantity must be positive'; end if;
 if not exists(select 1 from products where id=p_product and organization_id=p_org and active) then raise exception 'Product not found'; end if;
 insert into stock_movements(organization_id,product_id,movement_type,quantity,to_location,reference,actor) values(p_org,p_product,'RECEIVE',p_quantity,p_to_location,p_reference,auth.uid()) returning jsonb_build_object('id',id,'type',movement_type,'quantity',quantity) into result;
 update products set on_hand=on_hand+p_quantity where id=p_product;
 return result;
end; $$;

create or replace function public.transfer_stock(p_org uuid,p_product uuid,p_quantity integer,p_from_location uuid,p_to_location uuid,p_reference text default '') returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb; available integer;
begin perform assert_org_member(p_org); if p_quantity<=0 then raise exception 'Quantity must be positive'; end if;
 select count(*) into available from inventory_units u join products p on p.id=u.product_id where p.id=p_product and p.organization_id=p_org and u.location_id=p_from_location and u.status='IN_STOCK';
 if available<p_quantity then raise exception 'Insufficient tagged stock at source location'; end if;
 update inventory_units set location_id=p_to_location,updated_at=now() where id in(select u.id from inventory_units u where u.product_id=p_product and u.location_id=p_from_location and u.status='IN_STOCK' limit p_quantity);
 insert into stock_movements(organization_id,product_id,movement_type,quantity,from_location,to_location,reference,actor) values(p_org,p_product,'TRANSFER',p_quantity,p_from_location,p_to_location,p_reference,auth.uid()) returning jsonb_build_object('id',id,'type',movement_type,'quantity',quantity) into result;
 return result;
end; $$;

create or replace function public.dispatch_stock(p_org uuid,p_product uuid,p_quantity integer,p_from_location uuid,p_reference text default '') returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin perform assert_org_member(p_org); if p_quantity<=0 then raise exception 'Quantity must be positive'; end if;
 if (select count(*) from inventory_units u join products p on p.id=u.product_id where p.id=p_product and p.organization_id=p_org and u.location_id=p_from_location and u.status='IN_STOCK')<p_quantity then raise exception 'Insufficient stock for dispatch'; end if;
 update inventory_units set status='DISPATCHED',updated_at=now() where id in(select u.id from inventory_units u where u.product_id=p_product and u.location_id=p_from_location and u.status='IN_STOCK' limit p_quantity);
 update products set on_hand=on_hand-p_quantity where id=p_product;
 insert into stock_movements(organization_id,product_id,movement_type,quantity,from_location,reference,actor) values(p_org,p_product,'DISPATCH',p_quantity,p_from_location,p_reference,auth.uid()) returning jsonb_build_object('id',id,'type',movement_type,'quantity',quantity) into result;
 return result;
end; $$;

create or replace function public.complete_stock_count(p_org uuid,p_product uuid,p_location uuid,p_observed integer,p_reference text default '') returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb; expected integer; variance integer;
begin perform assert_org_member(p_org); if p_observed<0 then raise exception 'Observed quantity cannot be negative'; end if;
 select count(*) into expected from inventory_units u join products p on p.id=u.product_id where p.id=p_product and p.organization_id=p_org and u.location_id=p_location and u.status='IN_STOCK'; variance:=p_observed-expected;
 insert into stock_movements(organization_id,product_id,movement_type,quantity,to_location,reference,actor) values(p_org,p_product,'COUNT',variance,p_location,p_reference,auth.uid()) returning jsonb_build_object('id',id,'type',movement_type,'expected',expected,'observed',p_observed,'variance',variance) into result;
 return result;
end; $$;

grant execute on function receive_stock(uuid,uuid,integer,uuid,text) to authenticated;
grant execute on function transfer_stock(uuid,uuid,integer,uuid,uuid,text) to authenticated;
grant execute on function dispatch_stock(uuid,uuid,integer,uuid,text) to authenticated;
grant execute on function complete_stock_count(uuid,uuid,uuid,integer,text) to authenticated;
