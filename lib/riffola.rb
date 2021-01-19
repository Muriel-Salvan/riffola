require 'riffola/chunk'

module Riffola

  # Return a list of Riff chunk objects stored in a file, from a given offset.
  # A chunk is defined as this:
  # * A name (4 bytes)
  # * A size (4 bytes by default)
  # * A header (0 bytes by default)
  # * Data (Size bytes)
  #
  # Parameters::
  # * *file* (String): The file name
  # * *offset* (Integer): The offset to read the file from [default: 0]
  # * *chunks_format* (Hash<String, Hash<Symbol,Object> >): Chunks format. See Chunk#initialize for details. [default = {}]
  # * *max_size* (Integer): Maximum readable size (starting from the file's offset) to retrieve chunks, or nil to read till the end of the file [default: nil]
  # * *parent_chunk* (Chunk or nil): Parent chunk, or nil if none [default: nil]
  # * *warnings* (Boolean): Do we activate warnings? [default: true]
  # * *debug* (Boolean): Do we activate debugging logs? [default: false]
  # * Proc: Optional code called for each chunk being decoded
  #   * Parameters::
  #     * *chunk* (Chunk): Chunk being decoded
  #   * Result::
  #     * Boolean: Do we continue decoding chunks?
  # Result::
  # * Array<Chunk>: The chunks list
  def self.read(file, offset: 0, chunks_format: {}, max_size: nil, parent_chunk: nil, warnings: true, debug: false)
    chunks = []
    max_size = File.size(file) - offset if max_size.nil?
    chunk = max_size > 0 ? Chunk.new(file,
      offset: offset,
      chunks_format: chunks_format,
      max_size: max_size,
      parent_chunk: parent_chunk,
      warnings: warnings,
      debug: debug
    ) : nil
    while !chunk.nil?
      chunks << chunk
      break if block_given? && !yield(chunk)
      chunk = chunk.next
    end
    chunks
  end

end
