# Loner [![Hex pm](http://img.shields.io/hexpm/v/loner.svg?style=flat)](https://hex.pm/packages/loner)

Loner provides a simple method for creating a registered, supervised
singleton process within a multi-node cluster with the help of Horde.

In other words, it allows you to create a process which has the following properties:
* Exactly one instance of it across your entire cluster of nodes
* Supervised, so it will be restarted on failure
* Registered, so that it can be located though a constant name

Read the [full documentation](https://hexdocs.pm/loner) on hexdocs.pm.

## Installation

Loner can be installed by adding `loner` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
[
{:loner, "~> 0.2.0"}
]
end
```

## Use



## License

Loner is published under the MIT license. See the file `LICENSE` for details.
