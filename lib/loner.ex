defmodule Loner do
  @moduledoc """
  Documentation for Loner.
  """

  @type child_spec() :: module()| module() | [term()]

  def name(name), do: {:via, Horde.Registry, {Loner.Registry, name}}

  def start(module, name) do
    Horde.DynamicSupervisor.start_child(Loner.DynamicSupervisor, {module, name})
  end
end
