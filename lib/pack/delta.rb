require_relative "./numbers"
require_relative "./xdelta"

class Pack
  class Delta

    Copy = Struct.new(:offset, :size) do
      def self.parse(input, byte)
        value  = Numbers::PackedInt56LE.read(input, byte)
        offset = value & 0xffffffff
        size   = value >> 32

        Copy.new(offset, size)
      end

      def to_s
        bytes = Numbers::PackedInt56LE.write((size << 32) | offset)
        bytes[0] |= 0x80
        bytes.pack("C*")
      end
    end

    Insert = Struct.new(:data) do
      def self.parse(input, byte)
        Insert.new(input.read(byte))
      end

      def to_s
        [data.bytesize, data].pack("Ca*")
      end
    end

    attr_reader :data

    def initialize(source, target)
      @data = sizeof(source) + sizeof(target)

      index ||= XDelta.create_index(source)

      delta = index.compress(target)
      delta.each { |op| @data.concat(op.to_s) }
    end

    private

    def sizeof(entry)
      bytes = Numbers::VarIntLE.write(entry.bytesize, 7)
      bytes.pack("C*")
    end

  end
end
