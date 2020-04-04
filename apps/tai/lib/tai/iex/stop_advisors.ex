defmodule Tai.IEx.Commands.StopAdvisors do
  @type store_id_opt :: {:store_id, atom}
  @type where_opt :: {:where, list}
  @type options :: [store_id_opt | where_opt]

  @spec stop(options) :: no_return
  def stop(options) do
    {stopped, already_stopped} = Tai.Commander.stop_advisors(options)
    IO.puts("Stopped advisors: #{stopped} new, #{already_stopped} already stopped")
    IEx.dont_display_result()
  end
end
