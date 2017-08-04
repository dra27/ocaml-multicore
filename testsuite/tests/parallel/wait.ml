let rec await r =
  if Atomic.get r then () else await r

open Domain
open Domain.Sync

let go () =
  let in_crit = Atomic.make false in
  let woken = Atomic.make false in
  (* notify does actually notify *)
  let d = spawn (fun () ->
    critical_section (fun () ->
      Atomic.set in_crit true;
      wait ();
      Atomic.set in_crit false)) in
  await in_crit;
  notify (get_id d);
  (* notify does not return early *)
  assert (not (Atomic.get in_crit));
  join d;
  (* notify works even if it arrives before wait *)
  let entered_crit = Atomic.make false in
  let woken = Atomic.make false in
  let d = spawn (fun () ->
    critical_section (fun () ->
      Atomic.set entered_crit true;
      await woken;
      wait ())) in
  await entered_crit;
  Atomic.set woken true;
  notify (get_id d);
  join d;
  (* a single notification wakes all waits in a single crit sec *)
  let entered_crit = Atomic.make false in
  let in_second_crit = Atomic.make false in
  let d = spawn (fun () ->
    critical_section (fun () ->
      Atomic.set entered_crit true;
      wait ();
      wait ());
    critical_section (fun () ->
      Atomic.set in_second_crit true;
      wait ();
      Atomic.set in_second_crit false)) in
  await entered_crit;
  notify (get_id d);
  await in_second_crit;
  (* some busywork *)
  join (spawn (fun () -> ()));
  assert (Atomic.get in_second_crit);
  notify (get_id d);
  (* interrupt returns only after crit ends *)
  assert (not (Atomic.get in_second_crit));
  join d


let () =
  for i = 1 to 1000 do go () done;
  print_endline "ok"