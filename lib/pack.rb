require_relative "./pack/delta"
require_relative "./pack/expander"

class Pack
  GIT_MAX_COPY    = 0x10000
  MAX_COPY_SIZE   = 0xffffff
  MAX_INSERT_SIZE = 0x7f

  VERSION = 1

  FOOTER_FORMAT = "N2"
  FOOTER_SIZE   = 8

  ENTRY_FORMAT = "N4Q>"
  ENTRY_SIZE   = 24

  Entry = Struct.new(:offset, :full_size, :pack_size, :parent, :time) do
    def to_s
      to_a.map(&:to_i).pack(ENTRY_FORMAT)
    end
  end

  def initialize(path)
    @file  = File.open(path, File::RDWR | File::CREAT)
    @table = []

    load_table
  end

  def list
    @table
  end

  def add(source)
    src_size = source.bytesize

    if @table.empty?
      @file.seek(0, IO::SEEK_SET)
    else
      target = read_version(@table.size - 1)
      packed = Delta.new(source, target).data
      last   = @table.last

      @file.seek(last.offset, IO::SEEK_SET)
      @file.write(packed)

      last.pack_size = packed.bytesize
      last.parent    = @table.size
    end

    @table << Entry.new(@file.pos, src_size, src_size, 0, Time.now)
    @file.write(source)

    @table.each { |entry| @file.write(entry.to_s) }

    footer = [@version, @table.size].pack(FOOTER_FORMAT)
    @file.write(footer)
    @file.truncate(@file.pos)
  end

  def export(version = nil)
    version ||= @table.size
    read_version(version - 1)
  end

  private

  def read_version(version)
    entry = @table[version]

    @file.seek(entry.offset, IO::SEEK_SET)
    data = @file.read(entry.pack_size)

    return data if entry.parent == 0

    base = read_version(entry.parent)
    Expander.expand(base, data)
  end

  def load_table
    if @file.size == 0
      @version = VERSION
      return
    end

    @file.seek(-FOOTER_SIZE, IO::SEEK_END)
    @version, count = @file.read(FOOTER_SIZE).unpack(FOOTER_FORMAT)

    @file.seek(-FOOTER_SIZE - count * ENTRY_SIZE, IO::SEEK_END)

    count.times do
      ofs, f_size, p_size, parent, time = @file.read(ENTRY_SIZE).unpack(ENTRY_FORMAT)
      @table << Entry.new(ofs, f_size, p_size, parent, Time.at(time))
    end
  end
end
