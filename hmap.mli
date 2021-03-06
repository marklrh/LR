(* A value [(a, b) ordering] records the ordering between a value [l]
   of type [a t] and a value [r] of type [b t] for some type context
   [_ t].
   If [l] and [r] are equal then [a] must also be equal to [b];
   otherwise, there are no constraints on the types. *)
module type OrderedType =
sig
  type 'a t
  type 'a value
  val compare : 'a t -> 'b t -> ('a, 'b) Ordering.ordering
end

module type S =
  sig
    type _ key
    type _ value
    type t
    type iter = {iter: 'a. 'a key -> 'a value -> unit}
    type 'b fold = {fold: 'a. 'a key -> 'a value -> 'b -> 'b}
    val empty : t
    val is_empty : t -> bool
    val mem : 'a key -> t -> bool
    val add : 'a key -> 'a value -> t -> t
    val find : 'a key -> t -> 'a value option
    val union : t -> t -> t
    val iter : iter -> t -> unit
    val fold : 'a fold -> t -> 'a -> 'a
  end

module Make (Ord : OrderedType)
  : S with type 'a key = 'a Ord.t
       and type 'a value = 'a Ord.value
