require 'riffola'
require 'tempfile'
require 'hex_string'

describe Riffola do

  # Are we in debug mode?
  #
  # Result::
  # * Boolean: Are we in debug mode?
  def debug?
    ENV['TEST_DEBUG'] == '1'
  end

  HEX_DUMP_CHARS_SIZE = 16

  # Convert a given string in a debuggable hexadecimal format
  #
  # Parameters::
  # * *str* (String): String to be converted
  # Result::
  # * String: The output
  def hex_dump(str)
    str.scan(/.{1,#{HEX_DUMP_CHARS_SIZE}}/m).map do |line|
      "#{"%-#{HEX_DUMP_CHARS_SIZE * 3}s" % line.to_hex_string}| #{line.gsub(/[^[:print:]]/, '.')}"
    end.join("\n")
  end

  # Get a string encoding chunks
  #
  # Parameters::
  # * *chunks* (Array< Hash<Symbol,Object> >): List of chunks data:
  #   * *name* (String): Chunk's name
  #   * *data* (String): Chunk's data
  #   * *data_size* (Integer): Chunk's data size [default = data.size]
  #   * *header* (String): Chunk's header [default = '']
  #   * *size_length* (Integer): Size in bytes for size encoding [default = 4]
  # Result::
  # * String: The encoded chunks
  def chunks_to_str(chunks)
    chunks.map do |chunk_info|
      chunk_info[:header] = '' unless chunk_info.key?(:header)
      chunk_info[:size_length] = 4 unless chunk_info.key?(:size_length)
      chunk_info[:data_size] = chunk_info[:data].size unless chunk_info.key?(:data_size)
      size_pack_code =
        case chunk_info[:size_length]
        when 2
          'S'
        when 4
          'L'
        else
          raise "Unknown size length to encode: #{chunk_info[:size_length]}"
        end
      "#{chunk_info[:name]}#{[chunk_info[:data_size]].pack(size_pack_code)}#{chunk_info[:header]}#{chunk_info[:data]}"
    end.join
  end

  # Create a file with some chunks content and call code with its file name
  #
  # Parameters::
  # * *chunks* (Array< Hash<Symbol,Object> >): List of chunks data (check chunks for details). [default = []]:
  # * Proc: Code called once the file has been created. File is deleted after code execution.
  #   * Parameters::
  #     * *file* (String): File name
  def with_file_content(chunks = [])
    Tempfile.open do |tmp_file|
      tmp_file.write(chunks_to_str(chunks))
      tmp_file.flush
      puts "[Test Debug] - File #{tmp_file.path} has content:\n#{hex_dump(File.read(tmp_file))}" if debug?
      yield tmp_file.path
    end
  end

  # Return the chunks read from a file content
  #
  # Parameters::
  # * *chunks* (Array< Hash<Symbol,Object> >): List of chunks data. See with_file_content to understand the structure. [default = []]
  # * *chunks_format* (Object): The chunks_format parameter give to Riffola.read [default: {}]
  # * Proc: Code called with the chunks decoded from the file
  #   * Parameters::
  #     * *chunks* (Array<Riffola::Chunk>): List of chunks read from the file
  def read_chunks(chunks = [], chunks_format: {})
    with_file_content(chunks) do |file|
      yield Riffola.read(file, chunks_format: chunks_format, debug: debug?)
    end
  end

  it 'reads an empty file' do
    read_chunks do |chunks|
      expect(chunks).to eq []
    end
  end

  it 'reads a file containing 1 chunk' do
    chunk_name = 'ABCD'
    chunk_data = 'TestData'
    read_chunks([
      {
        name: chunk_name,
        data: chunk_data
      }
    ]) do |chunks|
      expect(chunks.size).to eq 1
      chunk = chunks.first
      expect(chunk.name).to eq chunk_name
      expect(chunk.size).to eq chunk_data.size
      expect(chunk.data).to eq chunk_data
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq nil
    end
  end

  it 'reads a file containing several chunks' do
    read_chunks([
      {
        name: 'CHK1',
        data: 'ChunkData1'
      },
      {
        name: 'CHK2',
        data: 'ChunkData2'
      },
      {
        name: 'CHK3',
        data: 'ChunkData3'
      }
    ]) do |chunks|
      expect(chunks.size).to eq 3
      chunk = chunks.first
      expect(chunk.name).to eq 'CHK1'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData1'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[1]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK2'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData2'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[2]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK3'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData3'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq nil
    end
  end

  it 'reads a file containing several chunks with size encoded in 2 bytes' do
    read_chunks([
      {
        name: 'CHK1',
        data: 'ChunkData1',
        size_length: 2
      },
      {
        name: 'CHK2',
        data: 'ChunkData2',
        size_length: 2
      },
      {
        name: 'CHK3',
        data: 'ChunkData3',
        size_length: 2
      }
    ], chunks_format: { '*' => { size_length: 2 } }) do |chunks|
      expect(chunks.size).to eq 3
      chunk = chunks.first
      expect(chunk.name).to eq 'CHK1'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData1'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[1]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK2'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData2'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[2]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK3'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData3'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq nil
    end
  end

  it 'reads a file containing several chunks with headers' do
    read_chunks([
      {
        name: 'CHK1',
        data: 'ChunkData1',
        header: 'ChunkHeader1'
      },
      {
        name: 'CHK2',
        data: 'ChunkData2',
        header: 'ChunkHeader2'
      },
      {
        name: 'CHK3',
        data: 'ChunkData3',
        header: 'ChunkHeader3'
      }
    ], chunks_format: { '*' => { header_size: 12 } }) do |chunks|
      expect(chunks.size).to eq 3
      chunk = chunks.first
      expect(chunk.name).to eq 'CHK1'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData1'
      expect(chunk.header).to eq 'ChunkHeader1'
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[1]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK2'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData2'
      expect(chunk.header).to eq 'ChunkHeader2'
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[2]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK3'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData3'
      expect(chunk.header).to eq 'ChunkHeader3'
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq nil
    end
  end

  it 'reads a file containing several chunks with data size correction' do
    read_chunks([
      {
        name: 'CHK1',
        data: 'ChunkData1',
        data_size: 4
      },
      {
        name: 'CHK2',
        data: 'ChunkData2',
        data_size: 4
      },
      {
        name: 'CHK3',
        data: 'ChunkData3',
        data_size: 4
      }
    ], chunks_format: { '*' => { data_size_correction: 6 } }) do |chunks|
      expect(chunks.size).to eq 3
      chunk = chunks.first
      expect(chunk.name).to eq 'CHK1'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData1'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[1]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK2'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData2'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[2]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK3'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData3'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq nil
    end
  end

  it 'reads a file containing several chunks with data size correction given as a Proc' do
    read_chunks([
      {
        name: 'CHK1',
        data: 'ChunkData1',
        data_size: 4
      },
      {
        name: 'CHK2',
        data: 'ChunkData2',
        data_size: 4
      },
      {
        name: 'CHK3',
        data: 'ChunkData3',
        data_size: 4
      }
    ], chunks_format: { '*' => { data_size_correction: proc { |_file| 6 } } }) do |chunks|
      expect(chunks.size).to eq 3
      chunk = chunks.first
      expect(chunk.name).to eq 'CHK1'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData1'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[1]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK2'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData2'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[2]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK3'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData3'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq nil
    end
  end

  it 'reads a file containing several chunks with data size correction on some chunks only' do
    read_chunks([
      {
        name: 'CHK1',
        data: 'ChunkData1'
      },
      {
        name: 'CHK2',
        data: 'ChunkData2',
        data_size: 4
      },
      {
        name: 'CHK3',
        data: 'ChunkData3',
        data_size: 14
      }
    ], chunks_format: { 'CHK2' => { data_size_correction: 6 }, 'CHK3' => { data_size_correction: -4 } }) do |chunks|
      expect(chunks.size).to eq 3
      chunk = chunks.first
      expect(chunk.name).to eq 'CHK1'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData1'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[1]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK2'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData2'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[2]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK3'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData3'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq nil
    end
  end

  it 'reads a file containing several chunks with sub-chunks' do
    chunk2_data = chunks_to_str([
      {
        name: 'SCK1',
        data: 'SubChunkData1'
      },
      {
        name: 'SCK2',
        data: 'SubChunkData2'
      },
      {
        name: 'SCK3',
        data: 'SubChunkData3'
      }
    ])
    read_chunks([
      {
        name: 'CHK1',
        data: 'ChunkData1'
      },
      {
        name: 'CHK2',
        data: chunk2_data
      },
      {
        name: 'CHK3',
        data: 'ChunkData3'
      }
    ]) do |chunks|
      expect(chunks.size).to eq 3
      chunk = chunks.first
      expect(chunk.name).to eq 'CHK1'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData1'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[1]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK2'
      expect(chunk.size).to eq chunk2_data.size
      expect(chunk.data).to eq chunk2_data
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[2]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK3'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData3'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq nil
      sub_chunks = chunks[1].sub_chunks
      expect(sub_chunks.size).to eq 3
      chunk = sub_chunks.first
      expect(chunk.name).to eq 'SCK1'
      expect(chunk.size).to eq 13
      expect(chunk.data).to eq 'SubChunkData1'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq chunks[1]
      expect(chunk.next).to eq sub_chunks[1]
      chunk = chunk.next
      expect(chunk.name).to eq 'SCK2'
      expect(chunk.size).to eq 13
      expect(chunk.data).to eq 'SubChunkData2'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq chunks[1]
      expect(chunk.next).to eq sub_chunks[2]
      chunk = chunk.next
      expect(chunk.name).to eq 'SCK3'
      expect(chunk.size).to eq 13
      expect(chunk.data).to eq 'SubChunkData3'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq chunks[1]
      expect(chunk.next).to eq nil
    end
  end

  it 'reads a file containing several chunks with sub-chunks having specific formats' do
    chunk2_data = chunks_to_str([
      {
        name: 'SCK1',
        data: 'SubChunkData1'
      },
      {
        name: 'SCK2',
        data: 'SubChunkData2',
        data_size: 7
      },
      {
        name: 'SCK3',
        data: 'SubChunkData3'
      }
    ])
    read_chunks([
      {
        name: 'CHK1',
        data: 'ChunkData1'
      },
      {
        name: 'CHK2',
        data: chunk2_data
      },
      {
        name: 'CHK3',
        data: 'ChunkData3'
      }
    ], chunks_format: { 'SCK2' => { data_size_correction: 6 } }) do |chunks|
      expect(chunks.size).to eq 3
      chunk = chunks.first
      expect(chunk.name).to eq 'CHK1'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData1'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[1]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK2'
      expect(chunk.size).to eq chunk2_data.size
      expect(chunk.data).to eq chunk2_data
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq chunks[2]
      chunk = chunk.next
      expect(chunk.name).to eq 'CHK3'
      expect(chunk.size).to eq 10
      expect(chunk.data).to eq 'ChunkData3'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq nil
      expect(chunk.next).to eq nil
      sub_chunks = chunks[1].sub_chunks
      expect(sub_chunks.size).to eq 3
      chunk = sub_chunks.first
      expect(chunk.name).to eq 'SCK1'
      expect(chunk.size).to eq 13
      expect(chunk.data).to eq 'SubChunkData1'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq chunks[1]
      expect(chunk.next).to eq sub_chunks[1]
      chunk = chunk.next
      expect(chunk.name).to eq 'SCK2'
      expect(chunk.size).to eq 13
      expect(chunk.data).to eq 'SubChunkData2'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq chunks[1]
      expect(chunk.next).to eq sub_chunks[2]
      chunk = chunk.next
      expect(chunk.name).to eq 'SCK3'
      expect(chunk.size).to eq 13
      expect(chunk.data).to eq 'SubChunkData3'
      expect(chunk.header).to eq ''
      expect(chunk.parent_chunk).to eq chunks[1]
      expect(chunk.next).to eq nil
    end
  end

end
