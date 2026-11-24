# test/DataGovAu/ABR/Rebuild_test.rb

require_relative '../../helper'

describe DataGovAu::ABR::Rebuild do
  # The delta and frame as a comparison writes them, before they are checked, so that each test can spoil one or the other.
  def compared(directory)
    older, newer = two_releases(directory)
    comparison = DataGovAu::ABR::Comparison.new(older, newer)
    comparison.write
    [older, newer, "#{newer.delta_path}.partial", "#{newer.frame_path}.partial"]
  end

  def rebuild(older, delta_path, frame_path)
    DataGovAu::ABR::Rebuild.new(older, DataGovAu::ABR::Delta.new(delta_path), DataGovAu::ABR::Frame.read(frame_path))
  end

  def rebuilt_files(rebuild)
    rebuild.each_piece.each_with_object(Hash.new{|hash, name| hash[name] = String.new}){|(member, piece), files| files[member.name] << piece}
  end

  describe "from the release before and its delta" do
    it "writes out each file of the newer release byte for byte" do
      Dir.mktmpdir do |directory|
        older, _newer, delta_path, frame_path = compared(directory)
        expected = newer_files.values.inject(:merge).transform_values(&:b)
        _(rebuilt_files(rebuild(older, delta_path, frame_path))).must_equal expected
      end
    end

    # Records added and removed shift which records fall hundredth, so the gaps of the newer release are its own and not the older's.
    it "writes out files running past a hundred records, gaps and all" do
      Dir.mktmpdir do |directory|
        held = abns(260)
        older = {'public_split_1_10.zip' => {'20261028_Public01.xml' => member_text(1, held.collect{|abn| record_line(abn)})}}
        kept = (held - [held[3], held[150]] + ['10000000002', '10000002000']).sort
        newer_text = member_text(1, kept.collect{|abn| record_line(abn, status: abn == held[40] ? 'CAN' : 'ACT')})
        newer = {'public_split_1_10.zip' => {'20261104_Public01.xml' => newer_text}}
        older_release, newer_release = two_releases(directory, older, newer)
        DataGovAu::ABR::Comparison.new(older_release, newer_release).write
        built = rebuilt_files(rebuild(older_release, "#{newer_release.delta_path}.partial", "#{newer_release.frame_path}.partial"))
        _(built['20261104_Public01.xml']).must_equal newer_text.b
      end
    end

    it "passes its check" do
      Dir.mktmpdir do |directory|
        older, _newer, delta_path, frame_path = compared(directory)
        _(rebuild(older, delta_path, frame_path).check).must_be_kind_of DataGovAu::ABR::Rebuild
      end
    end
  end

  describe "from a delta or frame which does not fit" do
    it "names the file which rebuilt otherwise" do
      Dir.mktmpdir do |directory|
        older, _newer, delta_path, frame_path = compared(directory)
        frame = DataGovAu::ABR::Frame.read(frame_path)
        frame.members.last.after = "\r\n</Transfer>\r\n".b
        frame.write(frame_path)
        error = _(->{rebuild(older, delta_path, frame_path).check}).must_raise DataGovAu::ABR::RebuildMismatch
        _(error.message).must_include '20261104_Public11.xml'
        _(error.message).wont_include '20261104_Public01.xml'
      end
    end

    it "stops at a delta adding an ABN the older release already holds" do
      Dir.mktmpdir do |directory|
        older, _newer, delta_path, frame_path = compared(directory)
        DataGovAu::ABR::Delta.new(delta_path).write{|changes| changes.add(record_line('11111111111'))}
        _(->{rebuild(older, delta_path, frame_path).check}).must_raise DataGovAu::ABR::RebuildMismatch
      end
    end

    it "stops at a delta changing an ABN the older release does not hold" do
      Dir.mktmpdir do |directory|
        older, _newer, delta_path, frame_path = compared(directory)
        DataGovAu::ABR::Delta.new(delta_path).write{|changes| changes.change(record_line('99999999999'))}
        _(->{rebuild(older, delta_path, frame_path).check}).must_raise DataGovAu::ABR::RebuildMismatch
      end
    end

    it "stops where the frame counts more records than there are" do
      Dir.mktmpdir do |directory|
        older, _newer, delta_path, frame_path = compared(directory)
        frame = DataGovAu::ABR::Frame.read(frame_path)
        frame.members.last.records += 1
        frame.write(frame_path)
        _(->{rebuild(older, delta_path, frame_path).check}).must_raise DataGovAu::ABR::RebuildMismatch
      end
    end

    it "stops where the frame counts fewer records than there are" do
      Dir.mktmpdir do |directory|
        older, _newer, delta_path, frame_path = compared(directory)
        frame = DataGovAu::ABR::Frame.read(frame_path)
        frame.members.last.records -= 1
        frame.write(frame_path)
        _(->{rebuild(older, delta_path, frame_path).check}).must_raise DataGovAu::ABR::RebuildMismatch
      end
    end

    it "stops where the frame was made against another release" do
      Dir.mktmpdir do |directory|
        older, _newer, delta_path, frame_path = compared(directory)
        frame = DataGovAu::ABR::Frame.read(frame_path)
        DataGovAu::ABR::Frame.new('20261021', frame.members).write(frame_path)
        _(->{rebuild(older, delta_path, frame_path).check}).must_raise DataGovAu::ABR::RebuildMismatch
      end
    end
  end
end
