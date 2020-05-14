defmodule Poker.Components.Timer do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <section class="phx-hero">
      <h1>"Enter your name"</h1>

      <form phx-submit="login">
        <input type="text" name="name" placeholder="Enter your name" autocomplete="off"/>
        <button type="submit">Enter</button>
      </form>
    </section>
    """
  end
end
