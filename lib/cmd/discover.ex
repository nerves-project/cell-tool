defmodule Nerves.Cell.CLI.Cmd.Discover do
  @moduledoc """
  Discovers cells on the Local network and displays key information such as
  the last octet of their IP, serial number, device type and firmware version.
  """

  alias Nerves.CLI.Cell.JRTP
  alias Nerves.CLI.Cell.Finder
  alias Nerves.CLI.Cell.Inet
  alias Nerves.CLI.Cell.Render

  # HACK: this duplicates configuration elsewhere in order to choose format
  # would be better to abstract out somehwere else.
  @nerves_st "urn:nerves-project-org:service:cell:1"

  @doc false
  def run(spec, _opts \\ %{}) do
#    HTTPotion.start
    spec
    |> Finder.discover
    |> Render.summary("Found")
    |> Render.table([:name, :ip, :usn])
  end

  defp format_status(service = %{st: @nerves_st}) do
    format_basic_status(service, service[:cellid])
  end
  defp format_status(service) do
    case service[:location] do
      nil ->
        format_basic_status(service)
      location ->
        case JRTP.get_cell_services_resource(location) do
          {:ok, services_resource} ->
            format_extended_status(service, services_resource)
          {:error, {:http, x}} ->
            format_basic_status(service, "HTTP #{x}")
          {:error, other} ->
            format_basic_status(service, "ERROR: #{inspect other}")
        end
    end
  end

  defp format_basic_status(cell, msg \\ "") do
    ip = Inet.ntoa(cell[:ip])
    name = cell[:name]
    st = cell[:st]
    usn = cell[:usn]
    "#{name}\t#{ip}\t#{usn}\t#{msg}"
  end

  # needs to be taken out and shot - gh 3-2016
  defp format_extended_status(cell, resource) do
    case resource.root.description do
      description when is_bitstring(description) -> # v2
        sf = resource.firmware
        sn = resource.root.serial_number
        model = resource.root.model
        case sf[:info] do
          nil ->
            fv = "BROKEN"
            fs = "BROKEN"
          fi ->
            fv = fi.version
            fs = fi.status
        end
      srd -> # v1
        fv = srd.firmware_version
        fs = srd.firmware_status
        sn = srd.serial_number
        model = srd.device_id
    end

    ip = Inet.ntoa(cell[:ip])
    case fs do
      "normal" ->
        "#{ip}\t#{cell.name}\t#{sn}\t#{model}\t#{fv}"
      _fw_status ->
        "#{ip}\t#{cell.name}\t#{sn}\t#{model}\t#{fv} (#{fs})"
    end
  end

end