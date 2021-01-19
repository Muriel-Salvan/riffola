module Riffola

  class Chunk

    # Define default chunk format properties
    DEFAULT_CHUNK_FORMAT = {
      size_length: 4,
      header_size: 0,
      data_size_correction: 0
    }

    # Constructor
    #
    # Parameters::
    # * *file_name* (String): The file name
    # * *offset* (Integer): The offset to read the file from [default: 0]
    # * *chunks_format* (Hash<String, Hash<Symbol,Object> >): Format of a given set of chunk names (use '*' for all chunks). For each chunk name, the following can be specified: [default = {}]
    #   * *size_length* (Integer): Number of bytes encoding the size of the chunk [default: 4]
    #   * *header_size* (Integer): Size of the chunk's header [default: 0]
    #   * *data_size_correction* (Integer): Correction to apply to the data size read [default: 0]
    #   Each property can also be a Proc taking the file handle (positioned at the beginning of the chunk) and returning the real value:
    #     * Parameters::
    #       * *file* (IO): The file IO, positioned at the beginning of the chunk (at the name)
    #     * Result::
    #       * Object: The corresponding property value
    # * *max_size* (Integer): Maximum readable size (starting from the file's offset) to retrieve chunks, or nil to read till the end of the file [default: nil]
    # * *parent_chunk* (Chunk or nil): Parent chunk, or nil if none [default: nil]
    # * *warnings* (Boolean): Do we activate warnings? [default: true]
    # * *debug* (Boolean): Do we activate debugging logs? [default: false]
    def initialize(file_name, offset: 0, chunks_format: {}, max_size: nil, parent_chunk: nil, warnings: true, debug: false)
      @file_name = file_name
      @offset = offset
      @chunks_format = chunks_format
      # Fill the default format if not present
      @chunks_format['*'] = {} unless @chunks_format.key?('*')
      DEFAULT_CHUNK_FORMAT.each do |format_property, default_property_value|
        @chunks_format['*'][format_property] = default_property_value unless @chunks_format['*'].key?(format_property)
      end
      @parent_chunk = parent_chunk
      @max_size = max_size.nil? ? File.size(@file_name) - @offset : max_size
      @warnings = warnings
      @debug = debug
      # Get chunk format in instance variables named after the property
      chunk_name = self.name
      DEFAULT_CHUNK_FORMAT.keys.each do |format_property|
        property_value = @chunks_format.key?(chunk_name) && @chunks_format[chunk_name].key?(format_property) ? @chunks_format[chunk_name][format_property] : @chunks_format['*'][format_property]
        if property_value.is_a?(Proc)
          File.open(@file_name) do |file|
            file.seek(@offset)
            property_value = property_value.call(file)
          end
        end
        instance_variable_set(:"@#{format_property}", property_value)
      end
      puts "[DEBUG] - Read chunk from #{@file_name}@#{@offset}/#{@max_size}: #{chunk_name} (size length: #{@size_length}, header size: #{@header_size}, data size: #{self.size}/#{@max_size})" if @debug
      # puts "[DEBUG] - Chunks format: #{@chunks_format.inspect}" if @debug
    end

    # Return the name of this chunk
    #
    # Result::
    # * String: Chunk name
    def name
      chunk_name = nil
      File.open(@file_name) do |file|
        file.seek(@offset, IO::SEEK_CUR)
        chunk_name = file.read(4)
      end
      puts "[WARNING] - Doesn't look like a valid chunk name: #{chunk_name}" if @warnings && !chunk_name =~ /^[\w ]{4}$/
      chunk_name
    end

    # Return the size of this chunk
    #
    # Result::
    # * Integer: Chunk size in bytes
    def size
      chunk_size = nil
      File.open(@file_name) do |file|
        file.seek(@offset + 4, IO::SEEK_CUR)
        case @size_length
        when 4
          chunk_size = file.read(@size_length).unpack('L').first
        when 2
          chunk_size = file.read(@size_length).unpack('S').first
        else
          raise "Can't decode size field of length #{@size_length}"
        end
      end
      chunk_size + @data_size_correction
    end

    # Return the header of this chunk
    #
    # Result::
    # * String: Header
    def header
      chunk_header = nil
      File.open(@file_name) do |file|
        file.seek(@offset + 4 + @size_length, IO::SEEK_CUR)
        chunk_header = file.read(@header_size)
      end
      chunk_header
    end

    # Return the data of this chunk
    #
    # Result::
    # * String: Data
    def data
      chunk_data = nil
      data_size = self.size
      complete_header_size = 4 + @size_length + @header_size
      puts "[WARNING] - Data size is #{data_size} but the maximum readable size is #{@max_size} and the headers have #{complete_header_size}" if @warnings && complete_header_size + data_size > @max_size
      File.open(@file_name) do |file|
        file.seek(@offset + complete_header_size, IO::SEEK_CUR)
        chunk_data = file.read(data_size)
      end
      chunk_data
    end

    # Return the parent chunk, or nil if none
    #
    # Result::
    # * Chunk or nil: The parent chunk, or nil if none
    def parent_chunk
      @parent_chunk
    end

    # Return a string representation of this chunk
    #
    # Result::
    # * String: tring representation of this chunk
    def to_s
      "<Riffola-Chunk #{self.name} (#{@file_name}@#{@offset})>"
    end

    # Return the next chunk
    #
    # Result::
    # * Chunk or nil: The next chunk, or nil if none
    def next
      complete_chunk_size = 4 + @size_length + @header_size + self.size
      remaining_size = @max_size - complete_chunk_size
      raise "#{self} - Remaining size for next chunk: #{remaining_size}" if remaining_size < 0
      remaining_size > 0 ? Chunk.new(@file_name,
        offset: @offset + complete_chunk_size,
        chunks_format: @chunks_format,
        max_size: remaining_size,
        parent_chunk: @parent_chunk,
        warnings: @warnings,
        debug: @debug
      ) : nil
    end

    # Return this chunk's data as a list of sub-chunks
    #
    # Parameters::
    # * *data_offset* (Integer): The offset to read the sub-chunks from this chunk's data [default: 0]
    # * *sub_chunks_format* (Hash<String, Hash<Symbol,Object> >): Chunks format. See Chunk#initialize for details. [default = @chunks_format]
    # * *warnings* (Boolean): Do we activate warnings? [default: @warnings]
    # * *debug* (Boolean): Do we activate debugging logs? [default: @debug]
    # * Proc: Optional code called for each chunk being decoded
    #   * Parameters::
    #     * *chunk* (Chunk): Chunk being decoded
    #   * Result::
    #     * Boolean: Do we continue decoding chunks?
    # Result::
    # * Array<Chunk>: List of sub-chunks
    def sub_chunks(data_offset: 0, sub_chunk_size_length: @size_length, sub_chunk_header_size: @header_size, sub_chunks_format: @chunks_format, warnings: @warnings, debug: @debug, &callback)
      data_size = self.size
      data_size > 0 ? Riffola.read(@file_name,
        offset: @offset + 4 + @size_length + @header_size + data_offset,
        chunks_format: sub_chunks_format,
        max_size: data_size - data_offset,
        parent_chunk: self,
        warnings: @warnings,
        debug: @debug,
        &callback
      ) : []
    end

    # Compare Chunks
    #
    # Parameters::
    # * *other* (Object): Other object
    # Result::
    # * Boolean: Are objects equal?
    def ==(other)
      other.is_a?(Chunk) &&
        other.name == self.name &&
        other.size == self.size &&
        other.header == self.header &&
        other.data == self.data
    end

  end

end
