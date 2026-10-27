//// The JSON derivers, through functions written exactly as `@derive`
//// writes them (`bea transpile` shows the same code for a derived type).

import bea_codecs/json/decoder
import bea_codecs/json/encoder
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}

pub type Address {
  Address(street: String, city: String)
}

pub type User {
  User(
    name: String,
    age: Int,
    score: Float,
    admin: Bool,
    tags: List(String),
    nick: Option(String),
    address: Address,
    counts: Dict(String, Int),
  )
}

// What `@derive(decoder, encoder)` defines for the two types.

fn address_decoder() {
  use <- decoder.record("Address")
  use street <- decoder.field("street", decoder.string(), fn(v: Address) {
    v.street
  })
  use city <- decoder.field("city", decoder.string(), fn(v: Address) { v.city })
  decoder.done(Address(street:, city:))
}

fn address_encoder() {
  use <- encoder.record("Address")
  use street <- encoder.field("street", encoder.string(), fn(v: Address) {
    v.street
  })
  use city <- encoder.field("city", encoder.string(), fn(v: Address) { v.city })
  encoder.done(Address(street:, city:))
}

fn user_decoder() {
  use <- decoder.record("User")
  use name <- decoder.field("name", decoder.string(), fn(v: User) { v.name })
  use age <- decoder.field("age", decoder.int(), fn(v: User) { v.age })
  use score <- decoder.field("score", decoder.float(), fn(v: User) { v.score })
  use admin <- decoder.field("admin", decoder.bool(), fn(v: User) { v.admin })
  use tags <- decoder.field("tags", decoder.list(decoder.string()), fn(v: User) {
    v.tags
  })
  use nick <- decoder.field(
    "nick",
    decoder.option(decoder.string()),
    fn(v: User) { v.nick },
  )
  use address <- decoder.field("address", address_decoder(), fn(v: User) {
    v.address
  })
  use counts <- decoder.field(
    "counts",
    decoder.dict(decoder.string(), decoder.int()),
    fn(v: User) { v.counts },
  )
  decoder.done(User(
    name:,
    age:,
    score:,
    admin:,
    tags:,
    nick:,
    address:,
    counts:,
  ))
}

fn user_encoder() {
  use <- encoder.record("User")
  use name <- encoder.field("name", encoder.string(), fn(v: User) { v.name })
  use age <- encoder.field("age", encoder.int(), fn(v: User) { v.age })
  use score <- encoder.field("score", encoder.float(), fn(v: User) { v.score })
  use admin <- encoder.field("admin", encoder.bool(), fn(v: User) { v.admin })
  use tags <- encoder.field("tags", encoder.list(encoder.string()), fn(v: User) {
    v.tags
  })
  use nick <- encoder.field(
    "nick",
    encoder.option(encoder.string()),
    fn(v: User) { v.nick },
  )
  use address <- encoder.field("address", address_encoder(), fn(v: User) {
    v.address
  })
  use counts <- encoder.field(
    "counts",
    encoder.dict(encoder.string(), encoder.int()),
    fn(v: User) { v.counts },
  )
  encoder.done(User(
    name:,
    age:,
    score:,
    admin:,
    tags:,
    nick:,
    address:,
    counts:,
  ))
}

const ada_json = "{\"name\":\"Ada\",\"age\":36,\"score\":4.5,\"admin\":true,\"tags\":[\"ops\"],\"nick\":\"ada\",\"address\":{\"street\":\"1 Hive Lane\",\"city\":\"Kanpur\"},\"counts\":{\"logins\":3}}"

fn ada() -> User {
  User(
    name: "Ada",
    age: 36,
    score: 4.5,
    admin: True,
    tags: ["ops"],
    nick: Some("ada"),
    address: Address("1 Hive Lane", "Kanpur"),
    counts: dict.from_list([#("logins", 3)]),
  )
}

pub fn decodes_a_record_test() {
  assert decoder.from_json(ada_json, user_decoder()) == Ok(ada())
}

pub fn encodes_a_record_test() {
  assert encoder.to_string(ada(), user_encoder()) == ada_json
}

pub fn round_trips_test() {
  let user = User(..ada(), nick: None, tags: [], counts: dict.new())
  let text = encoder.to_string(user, user_encoder())
  assert decoder.from_json(text, user_decoder()) == Ok(user)
}

pub fn none_is_null_test() {
  let text = encoder.to_string(User(..ada(), nick: None), user_encoder())
  assert text
    == "{\"name\":\"Ada\",\"age\":36,\"score\":4.5,\"admin\":true,\"tags\":[\"ops\"],\"nick\":null,\"address\":{\"street\":\"1 Hive Lane\",\"city\":\"Kanpur\"},\"counts\":{\"logins\":3}}"
}

pub fn an_option_may_be_null_or_missing_test() {
  let with_null =
    "{\"name\":\"Ada\",\"age\":36,\"score\":4.5,\"admin\":true,\"tags\":[],\"nick\":null,\"address\":{\"street\":\"s\",\"city\":\"c\"},\"counts\":{}}"
  let missing =
    "{\"name\":\"Ada\",\"age\":36,\"score\":4.5,\"admin\":true,\"tags\":[],\"address\":{\"street\":\"s\",\"city\":\"c\"},\"counts\":{}}"
  let assert Ok(a) = decoder.from_json(with_null, user_decoder())
  let assert Ok(b) = decoder.from_json(missing, user_decoder())
  assert a.nick == None
  assert b.nick == None
}

pub fn a_float_accepts_an_integer_test() {
  let text =
    "{\"name\":\"Ada\",\"age\":36,\"score\":4,\"admin\":true,\"tags\":[],\"address\":{\"street\":\"s\",\"city\":\"c\"},\"counts\":{}}"
  let assert Ok(user) = decoder.from_json(text, user_decoder())
  assert user.score == 4.0
}

pub fn errors_name_the_failing_field_test() {
  let text =
    "{\"name\":\"Ada\",\"age\":\"old\",\"score\":4.5,\"admin\":true,\"tags\":[],\"address\":{\"street\":5,\"city\":\"c\"},\"counts\":{}}"
  let assert Error(json.UnableToDecode(errors)) =
    decoder.from_json(text, user_decoder())
  assert errors
    == [
      decode.DecodeError("Int", "String", ["age"]),
      decode.DecodeError("String", "Int", ["address", "street"]),
    ]
}

pub fn a_missing_field_is_an_error_test() {
  let assert Error(json.UnableToDecode([error])) =
    decoder.from_json("{\"street\":\"s\"}", address_decoder())
  assert error.path == ["city"]
}

pub fn invalid_json_is_an_error_test() {
  let assert Error(json.UnexpectedEndOfInput) =
    decoder.from_json("{\"street\":", address_decoder())
}

pub fn derived_decoders_are_standard_decoders_test() {
  let assert Ok(addresses) =
    json.parse(
      "[{\"street\":\"s\",\"city\":\"c\"}]",
      decode.list(address_decoder()),
    )
  assert addresses == [Address("s", "c")]
}

pub fn to_json_gives_a_json_value_test() {
  let value = encoder.to_json(Address("s", "c"), address_encoder())
  assert json.to_string(json.array([value], fn(v) { v }))
    == "[{\"street\":\"s\",\"city\":\"c\"}]"
}
