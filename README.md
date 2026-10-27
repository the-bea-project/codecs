# bea_codecs

[![Package Version](https://img.shields.io/hexpm/v/bea_codecs)](https://hex.pm/packages/bea_codecs)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/bea_codecs/)
[![Guide](https://img.shields.io/badge/guide-read-8a2be2)](https://v4rm4n.github.io/bea_codecs/)

**Serialization and deserialization codecs for [Bea](https://github.com/the-bea-project/bea).**

`bea_codecs` provides reusable encoders, decoders, and derivers for Bea's `@derive` system.

Bea's compiler generates ordinary functions that describe a type's structure. Each deriver decides how to interpret that structure, whether it's decoding JSON, encoding a record, or working with another data format.

The goal is simple: **define your types once and let the codecs handle the repetitive work.**

Built with Bea. Powered by Gleam.

## Installation

```sh
bea add bea_codecs
```

Add any required format dependencies separately. For JSON:

```sh
bea add gleam_json
```

## Supported formats

| Format | Decoding | Encoding | Modules |
|---|---|---|---|
| JSON | Yes | Yes | `bea_codecs/json/decoder`, `bea_codecs/json/encoder` |

Additional codecs can be introduced independently without changing the existing APIs.

## Quick start

```bea
import bea_codecs/json/decoder
import bea_codecs/json/encoder
import gleam/json

@derive(decoder, encoder)
pub type User {
  name: String,
  age: Int,
  tags: List(String),
  nick: Option(String),
}

pub def greet(body: String) -> Result(String, json.DecodeError) {
  user = decoder.from_json(body, User.decoder())?
  Ok("hello, #{user.name}")
}

pub def to_json(user: User) -> String {
  encoder.to_string(user, User.encoder())
}
```

`@derive(decoder, encoder)` generates two ordinary functions:

| Bea API | Generated Gleam function | Type |
|---|---|---|
| `User.decoder()` | `user_decoder()` | `decode.Decoder(User)` |
| `User.encoder()` | `user_encoder()` | `fn(User) -> Json` |

These are regular Gleam-compatible functions, not special runtime objects.

## Available codecs

### JSON

Modules:

```bea
import bea_codecs/json/decoder
import bea_codecs/json/encoder
```

JSON codecs use Gleam's standard `gleam/dynamic/decode` and `gleam/json` APIs.

#### Decoding

```bea
@derive(decoder)
pub type Credentials {
  username: String,
  password: String,
}

credentials = decoder.from_json(
  body,
  Credentials.decoder(),
)?
```

The generated decoder works with any API that accepts a standard `decode.Decoder`.

For example, it can be passed to `json.parse` or `decode.run` directly.

#### Encoding

```bea
@derive(encoder)
pub type Profile {
  username: String,
  age: Int,
}

profile = Profile(username: "alice", age: 25)

text = encoder.to_string(
  profile,
  Profile.encoder(),
)
```

Output:

```json
{"username":"alice","age":25}
```

#### JSON conventions

Records are represented as JSON objects, with one key per labelled field.

Supported field types include `String`, `Int`, `Float`, `Bool`, `List(a)`, `Option(a)`, `Dict(k, v)`, and custom record types with compatible derived or manually defined codecs.

**Decoding**

- Integers are accepted when a `Float` is expected.
- Missing optional fields decode as `None`.
- Explicit JSON `null` decodes as `None` for optional fields.
- Required fields must be present.
- Errors use Gleam's standard decoding errors, including the path to the invalid value.

For example:

```text
DecodeError("Int", "String", ["age"])
```

**Encoding**

- Records become JSON objects.
- `None` is encoded as JSON `null`.
- Dictionary keys must be `String` values.
- Nested records use their corresponding encoders.

**Custom types and unions**

Automatic derivation currently supports single-constructor records.

For multi-constructor types, define the corresponding decoder or encoder manually. Derived functions for records containing those types can use the manually provided functions.

#### JSON API

| Function | Description |
|---|---|
| `decoder.from_json(text, decoder)` | Decode JSON text into a typed Bea value |
| `encoder.to_json(value, encoder)` | Produce a `gleam/json.Json` value |
| `encoder.to_string(value, encoder)` | Serialize a value into JSON text |

## Working with multiple codecs

Each serialization format lives in its own module namespace.

For example, JSON codecs use:

```text
bea_codecs/json/decoder
bea_codecs/json/encoder
```

Future formats can follow the same structure:

```text
bea_codecs/<format>/decoder
bea_codecs/<format>/encoder
```

Deriver names are determined by their imported aliases.

```bea
import bea_codecs/json/decoder as json_decoder
import bea_codecs/json/encoder as json_encoder

@derive(json_decoder, json_encoder)
pub type User {
  name: String,
}
```

This produces:

```bea
User.json_decoder()
User.json_encoder()
```

The corresponding ordinary Gleam functions are:

```gleam
user_json_decoder()
user_json_encoder()
```

This allows multiple codecs to coexist for the same type without naming conflicts.

## Writing your own codec

Bea's derive system is extensible through ordinary modules.

A deriver does not need special compiler privileges. It provides functions that interpret a record's structure.

### Deriver interface

A record deriver provides three fundamental operations:

| Function | Responsibility |
|---|---|
| `record(constructor, fields)` | Start processing the record |
| `field(label, part, get, next)` | Process an individual field |
| `done(value)` | Finish processing the record |

The compiler generates calls to these operations based on the type definition.

For each supported field type, the deriver also provides a suitable operation such as `string`, `int`, `list`, or `option`.

The required function signatures depend on the representation produced by the deriver.

### Decoders and encoders

Decoders primarily use the `next` continuation to construct a value from decoded fields.

Encoders primarily use the `get` function to extract values from existing records.

This allows the same structural derivation mechanism to support two different operations.

For complete implementations, see:

- `src/bea_codecs/json/decoder.bea`
- `src/bea_codecs/json/encoder.bea`

### Adding a format

New codecs should be implemented under their own namespace:

```text
src/
└── bea_codecs/
    └── <format>/
        ├── decoder.bea
        └── encoder.bea
```

A format may initially support only decoding or only encoding. Both are not required.

Prefer building on existing Gleam libraries for parsing and serialization rather than duplicating their implementations.

Keep format-specific rules within the codec library, not in Bea's compiler.

## Project structure

```text
bea_codecs/
├── bea.toml
├── manifest.toml
├── README.md
├── CHANGELOG.md
├── src/
│   └── bea_codecs/
│       └── json/
│           ├── decoder.bea
│           └── encoder.bea
└── test/
    ├── bea_codecs_test.gleam
    └── bea_codecs/
        └── json_test.gleam
```

Each format should have its own implementation directory and corresponding test module.

Future codecs can be added without changing existing JSON imports.

## Development

Requires Bea and the Gleam toolchain.

```sh
bea build
bea test
bea format --check src
```

Tests are written in Gleam and exercise the same generated function structure that Bea's `@derive` produces.

To inspect generated Gleam:

```sh
bea transpile --out generated
```

### JavaScript tests

In Bea 0.3.0, `bea test --target javascript` has a known limitation involving gleeunit's project configuration lookup.

Run JavaScript tests from the generated Gleam project instead:

```sh
bea build
cd .beabuild
gleam test --target javascript
```

## Compatibility

`bea_codecs` is designed for Bea projects, but its derived functions and underlying types are ordinary Gleam.

Generated decoders use `gleam/dynamic/decode.Decoder`, and JSON encoders return `gleam/json.Json`.

The library is published as generated Gleam code, allowing Gleam projects to consume its public APIs directly.

This preserves compatibility with the Gleam ecosystem without introducing a Bea-specific serialization runtime.

## Publishing

Configure the package metadata in `bea.toml`, including its licence and repository information.

Then run:

```sh
bea publish
```

Bea publishes the generated Gleam package to Hex.

## Design philosophy

`bea_codecs` follows three principles:

**1. Ordinary Bea types**

Define records without writing repetitive serialization code.

**2. Extensible derivation**

A codec is an ordinary module. Different formats can implement their own conventions using the same deriving mechanism.

**3. Gleam interoperability**

Use existing Gleam libraries and standard types wherever possible. Serialization should not require a parallel runtime or ecosystem.

---

**bea_codecs** — Define the data. Derive the representation.