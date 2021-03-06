defmodule Nerves.Cell.CLI.Cmd.Push do
  @moduledoc false

  require Logger

  alias Nerves.Cell.CLI.Finder

  def run(context) do
    context
    |> Finder.discover(single: true)
    |> push_firmware
  end

  defp push_firmware(context) do
    #Logger.info "Got here, context: #{inspect context}"
    if (context[:firmware] == nil) do
      IO.puts "Push requires --firmware to be specified"
      :erlang.halt(1)
    end
    [{_id,cell}|_] = context.cells
    bits = File.read! context.firmware
    uri = target_uri(cell)
    #Logger.debug "Pushing #{:erlang.size(bits)} bytes from #{context.firmware} to #{uri}"
    HTTPotion.start
    HTTPotion.put(uri,
       body: bits,
       headers: ["Content-Type": "application/x-firmware","X-Reboot": "true"],
       timeout: 30000)
    |> handle_status
  end

  defp target_uri(cell) do
    location = cell[:location]
    case location do
      <<"http:", _rest::binary>> ->
        location
      <<"https:", _rest::binary>> ->
        location
      <<"/_cell/", _rest::binary>> ->  # broken legacy crap
        "http://#{cell.host}:8988/firmware"
      other ->
        IO.puts "Cell gives no valid location for firmware service (got #{other})"
        :erlang.halt(1)
    end
  end

  defp handle_status(%HTTPotion.Response{status_code: 201}) do
    IO.puts "Firmware succesfully updated"
  end
  defp handle_status(%HTTPotion.Response{status_code: x}) do
    IO.puts "Push firmware failed: HTTP #{x}"
    :erlang.halt(1)
  end
  defp handle_status(%HTTPotion.ErrorResponse{message: "connection_closed"}) do #HACK REVIEW this should be handled by graceful exit instead
    IO.puts "Firmware pushed, connection closed (device likely rebooting)"
  end
  defp handle_status(%HTTPotion.ErrorResponse{message: error_message}) do
    IO.puts "Push firmware failed: #{error_message}"
    :erlang.halt(1)
  end
end
