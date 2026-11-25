# test/DataGovAu/AbnBulkExtract/Lines_test.rb

require_relative '../../helper'

describe DataGovAu::AbnBulkExtract::Lines do
  let(:records){[record_line('11111111111'), record_line('22222222222', status: 'CAN'), record_line('33333333333')]}
  let(:text){member_text(1, records)}

  def read(text, name = '20261028_Public01.xml')
    lines = DataGovAu::AbnBulkExtract::Lines.new(StringIO.new(text.b), name)
    [lines, lines.each_record.to_a]
  end

  describe "a file laid out a record a line" do
    it "yields each record as its ABN and its text" do
      _lines, read_records = read(text)
      _(read_records).must_equal [['11111111111', records[0]], ['22222222222', records[1]], ['33333333333', records[2]]]
    end

    it "holds what comes before the first record and after the last" do
      lines, _read_records = read(text)
      _(lines.before).must_equal text[0...text.index('<ABR ')]
      _(lines.after).must_equal "\r\r\n</Transfer>\r\n"
      _(lines.records).must_equal 3
    end

    it "is given back exactly by its framing and its records" do
      lines, read_records = read(text)
      _(lines.before + read_records.collect(&:last).join("\r\n") + lines.after).must_equal text.b
    end

    it "hashes every byte read" do
      lines, _read_records = read(text)
      _(lines.sha256).must_equal Digest::SHA256.hexdigest(text)
    end

    it "notes the second carriage return the extract puts after every hundredth record" do
      lines, _read_records = read(member_text(1, abns(250).collect{|abn| record_line(abn)}))
      _(lines.gaps).must_equal({"\r\r\n" => [100, 200]})
    end

    it "notes nothing where every record is parted from the next by a line break" do
      lines, _read_records = read(text)
      _(lines.gaps).must_equal({})
    end

    it "frames a file holding no records" do
      lines, read_records = read(member_text(1, []))
      _(read_records).must_equal []
      _(lines.records).must_equal 0
      _(lines.before).must_equal member_text(1, []).b
      _(lines.after).must_equal ''
    end
  end

  describe "a file with more than a line break between two records" do
    it "holds what parts them, and after which record" do
      lines, _read_records = read(text.sub("</ABR>\r\n<ABR ", "</ABR>\r\n  \r\n<ABR "))
      _(lines.gaps).must_equal({"\r\n  \r\n" => [1]})
    end
  end

  # Such a file could not be written out again from its records, so it stops rather than being kept as a difference wrongly.
  describe "a file laid out otherwise" do
    it "stops at a record running over more than one line, as the files were once laid out" do
      _(->{read(File.binread(fixture_path('20261020Public01.xml')))}).must_raise DataGovAu::AbnBulkExtract::ExtractMalformed
    end

    it "stops at two records on one line" do
      _(->{read(text.sub("</ABR>\r\n<ABR ", '</ABR><ABR '))}).must_raise DataGovAu::AbnBulkExtract::ExtractMalformed
    end

    it "stops at a record carrying no ABN" do
      _(->{read(member_text(1, ['<ABR replaced="N"></ABR>']))}).must_raise DataGovAu::AbnBulkExtract::ExtractMalformed
    end
  end
end
