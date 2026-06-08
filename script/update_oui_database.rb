#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "json"
require "open-uri"

DEFAULT_URL = "https://standards-oui.ieee.org/oui/oui.csv"

def load_csv(source)
  if source.start_with?("http://", "https://")
    URI.open(source, read_timeout: 30, open_timeout: 10, "User-Agent" => "LanScopeMac-OUI-Updater").read
  else
    File.binread(source)
  end
end

def parse_oui_csv(data)
  vendors = {}
  CSV.parse(data.encode("UTF-8", invalid: :replace, undef: :replace), headers: true) do |row|
    assignment = row["Assignment"].to_s.delete("-:").upcase
    organization = row["Organization Name"].to_s.strip
    next unless assignment.match?(/\A[0-9A-F]{6}\z/) && !organization.empty?

    vendors[assignment] = organization
  end

  raise "OUI CSV did not contain vendor assignments" if vendors.empty?

  vendors.sort.to_h
end

source = DEFAULT_URL
output = "Resources/oui.json"

args = ARGV.dup
until args.empty?
  case args.shift
  when "--source"
    source = args.shift || abort("missing value for --source")
  when "--output"
    output = args.shift || abort("missing value for --output")
  when "--help", "-h"
    puts "usage: #{$PROGRAM_NAME} [--source URL_OR_CSV] [--output Resources/oui.json]"
    exit 0
  else
    abort("unknown argument")
  end
end

vendors = parse_oui_csv(load_csv(source))
File.write(output, "#{JSON.pretty_generate(vendors)}\n")
puts "wrote #{vendors.length} OUI records to #{output}"
