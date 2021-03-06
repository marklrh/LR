module type SetOrderedType2 =
sig
  type ('a, 'b) t
  val compare : ('a, 'b) t -> ('c, 'd) t -> ('e, 'e) Ordering.ordering
end

module type S =
  sig
    type (_, _) elem
    type t
    type iter = {iter:'a 'b. ('a, 'b) elem -> unit}
    type 'b fold = {fold:'a 'c. ('a, 'c) elem -> 'b -> 'b}
    val empty : t
    val is_empty : t -> bool
    val singleton : ('a, 'b) elem -> t
    val compare : t -> t -> int
    val mem : ('a, 'b) elem -> t -> bool
    val add : ('a, 'b) elem -> t -> t
    val union : t -> t -> t
    val cardinal : t -> int
    val iter : iter -> t -> unit
    val fold : 'a fold -> t -> 'a -> 'a
  end

module Make (Ord: SetOrderedType2) : S with type ('a, 'b) elem = ('a, 'b) Ord.t =
struct
  type ('a, 'b) elem = ('a, 'b) Ord.t

  type box = Box : ('a, 'b) elem -> box (* handle scope escaping *)

  (* Borrowed and adapted from OCaml's standard library.  The OCaml
     license (LGPL version 2 with linking exception) applies. *)
  type t =
      Empty
    | Node : t * ('a, 'b) elem * t * int -> t

  type iter = {iter:'a 'b. ('a, 'b) elem -> unit}
  type 'b fold = {fold:'a 'c. ('a, 'c) elem -> 'b -> 'b}

  let make_box : type a b. (a, b) elem -> box = fun elem -> Box elem

  let empty = Empty

  let is_empty = function
    | Empty -> true
    | _ -> false

  let singleton e = Node (Empty, e, Empty, 1)

  let height = function
      Empty -> 0
    | Node(_,_,_,h) -> h

  let create : 'a 'b. t -> ('a, 'b) elem -> t -> t =
    fun l x r ->
      let hl = height l and hr = height r in
      Node(l, x, r, (if hl >= hr then hl + 1 else hr + 1))

  let bal : 'a 'b. t -> ('a, 'b) elem -> t -> t =
    fun l x r ->
    let hl = match l with Empty -> 0 | Node(_,_,_,h) -> h in
    let hr = match r with Empty -> 0 | Node(_,_,_,h) -> h in
    if hl > hr + 2 then begin
      match l with
        Empty -> invalid_arg "Hmap.bal"
      | Node(ll, lv, lr, _) ->
          if height ll >= height lr then
            create ll lv (create lr x r)
          else begin
            match lr with
              Empty -> invalid_arg "Hmap.bal"
            | Node(lrl, lrv, lrr, _)->
                create (create ll lv lrl) lrv (create lrr x r)
          end
    end else if hr > hl + 2 then begin
      match r with
        Empty -> invalid_arg "Hmap.bal"
      | Node(rl, rv, rr, _) ->
          if height rr >= height rl then
            create (create l x rl) rv rr
          else begin
            match rl with
              Empty -> invalid_arg "Hmap.bal"
            | Node(rll, rlv, rlr, _) ->
                create (create l x rll) rlv (create rlr rv rr)
          end
    end else
      Node(l, x, r, (if hl >= hr then hl + 1 else hr + 1))

  let rec add : type a b. (a, b) elem -> t -> t =
    fun x -> function
      Empty ->
        Node(Empty, x, Empty, 1)
    | Node(l, v, r, h) ->
        match Ord.compare x v with
        | Ordering.EQ ->
          Node(l, x, r, h)
        | Ordering.LT ->
          let ll = add x l in
          bal ll v r
        | Ordering.GT ->
          let rr = add x r in
          bal l v rr

  let rec mem : type a b. (a, b) elem -> t -> bool =
   fun x -> function
      Empty ->
        false
    | Node(l, v, r, _) -> begin
        match Ord.compare x v with
        Ordering.EQ -> true
        | Ordering.LT -> mem x l
        | Ordering.GT -> mem x r
        end


  let singleton : type a b. (a, b) elem -> t = fun k ->
      Node (Empty, k, Empty, 1)

  let rec add_min_element : type a b. (a, b) elem -> t -> t =
    fun k t ->
      match t with
      | Empty -> singleton k
      | Node (l, k', r, h) ->
        bal (add_min_element k l) k' r

  let rec add_max_element : type a b. (a, b) elem -> t -> t =
    fun k t ->
      match t with
      | Empty -> singleton k
      | Node (l, k', r, h) ->
        bal l k' (add_min_element k r)

  let rec join l k r =
    match (l, r) with
    | (Empty, _) -> add_min_element k r
    | (_, Empty) -> add_max_element k l
    | Node (ll, lk, lr, lh), Node(rl, rk, rr, rh) ->
      if lh > rh + 2 then bal ll lk (join lr k r) else
      if rh > lh + 2 then bal (join l k rl) rk rr else
        create l k r

  let rec min_elt = function
    | Empty -> raise Not_found
    | Node (Empty, k, r, _) -> make_box k
    | Node (l, k, r, _) -> min_elt l

  let rec max_elt = function
    | Empty -> raise Not_found
    | Node (l, k, Empty, _) -> make_box k
    | Node (l, k, r, _) -> max_elt r

  let rec split : type a b. (a, b) elem -> t -> (t * bool * t) = fun k t ->
    match t with
    | Empty -> Empty, false, Empty
    | Node (l, k', r, _) -> begin
      match Ord.compare k k' with
      | Ordering.EQ -> l, true, r
      | Ordering.LT ->
        let ll, pres, rl = split k l in
        ll, pres, join rl k' r
      | Ordering.GT ->
        let lr, pres, rr = split k r in
        join l k' lr, pres, rr
      end

  let rec union : t -> t -> t = fun t1 t2 ->
    match (t1, t2) with
    | Empty, t2 -> t2
    | t1, Empty -> t1
    | Node (l1, k1, r1, h1), Node (l2, k2, r2, h2) ->
      if h1 >= h2 then
        if h2 = 1 then add k2 t1 else begin
          let (l2, _, r2) = split k1 t2 in
          join (union l1 l2) k1 (union r1 r2)
        end
      else
        if h1 = 1 then add k1 t2 else begin
          let (l1, _, r1) = split k2 t1 in
          join (union l1 l2) k2 (union r1 r2)
        end

  let rec cardinal = function
    | Empty -> 0
    | Node (l, _, r, _) -> 1 + cardinal l + cardinal r

  let rec iter it = function
    | Empty -> ()
    | Node (l, k, r, _) -> iter it l; it.iter k; iter it r

  let rec fold fd t acc =
    match t with
    | Empty -> acc
    | Node (l, v, r, _) -> fold fd r (fd.fold v (fold fd l acc))

  (* basically, the following two functions are fucked up *)

  let rec subset s1 s2 =
    match s1, s2 with
    | Empty, _ -> true
    | _, Empty -> false
    | Node (l1, v1, r1, _), (Node (l2, v2, r2, _) as t2) -> begin
      match Ord.compare v1 v2 with
      | Ordering.EQ -> subset l1 l2 && subset r1 r2
      | Ordering.LT -> subset (Node (l1, v1, Empty, 0)) l2 && subset r1 t2
      | Ordering.GT -> subset (Node (Empty, v1, r1, 0)) r2 && subset l1 t2
      end

  (* this is how normies compare two sets, damn! *)
  let compare s1 s2 =
    let f1: type a b. (a, b) elem -> bool -> bool =
      fun e accb -> accb && mem e s1 in
    let f2: type a b. (a, b) elem -> bool -> bool =
      fun e accb -> accb && mem e s2 in
    let b1 = fold {fold = f1} s2 true in
    let b2 = fold {fold = f2} s1 true in
    match b1, b2 with
    | true, true -> 0
    | true, false -> 1
    | false, true -> -1
    | false, false -> 1

end

