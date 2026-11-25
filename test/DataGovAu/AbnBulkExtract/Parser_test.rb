# test/DataGovAu/AbnBulkExtract/Parser_test.rb

require_relative '../../helper'

describe DataGovAu::AbnBulkExtract::Parser do
  describe "what the file says of itself" do
    it "reports the sequence number, the record count and the extract time" do
      parser = File.open(fixture_path('20261020Public01.xml'), 'rb'){|file| DataGovAu::AbnBulkExtract::Parser.new(file).each_record{}}
      _(parser.file_sequence_number).must_equal 1
      _(parser.record_count).must_equal 9
      _(parser.extract_time).must_equal '2026-10-20T03:17:42'
    end

    it "reports the error the file names, none where it was written out whole" do
      parser = File.open(fixture_path('20261020Public01.xml'), 'rb'){|file| DataGovAu::AbnBulkExtract::Parser.new(file).each_record{}}
      _(parser.error).must_equal 'none'
      _(parser.error_free?).must_equal true
    end

    # A file which gave up fewer records than it promised has been truncated, and is worth knowing about rather than passing as a smaller week.
    it "counts itself whole where it gave up as many records as it promised" do
      parser = File.open(fixture_path('20261020Public01.xml'), 'rb'){|file| DataGovAu::AbnBulkExtract::Parser.new(file).each_record{}}
      _(parser.records_parsed).must_equal 9
      _(parser.whole?).must_equal true
    end

    it "counts itself short where the file was cut off" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'cut.xml')
        whole = File.read(fixture_path('20261020Public01.xml'))
        File.write(path, whole[0, whole.rindex('<ABR ')] + '</Transfer>')
        parser = File.open(path, 'rb'){|file| DataGovAu::AbnBulkExtract::Parser.new(file).each_record{}}
        _(parser.records_parsed).must_equal 8
        _(parser.record_count).must_equal 9
        _(parser.whole?).must_equal false
      end
    end

    it "counts itself short where the file reports an error, every record yielded or not" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'erred.xml')
        File.write(path, File.read(fixture_path('20261020Public01.xml')).sub('<Transfer error="none">', '<Transfer error="partial">'))
        parser = File.open(path, 'rb'){|file| DataGovAu::AbnBulkExtract::Parser.new(file).each_record{}}
        _(parser.records_parsed).must_equal 9
        _(parser.error).must_equal 'partial'
        _(parser.whole?).must_equal false
      end
    end

    it "counts itself short where the file names no error at all" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'unnamed.xml')
        File.write(path, File.read(fixture_path('20261020Public01.xml')).sub('<Transfer error="none">', '<Transfer>'))
        parser = File.open(path, 'rb'){|file| DataGovAu::AbnBulkExtract::Parser.new(file).each_record{}}
        _(parser.error).must_be_nil
        _(parser.whole?).must_equal false
      end
    end
  end

  describe "the record it yields" do
    it "yields every record in the file" do
      _(fixture_records.length).must_equal 9
    end

    it "takes the ABN, its status and the date that status took effect" do
      record = fixture_record('11111111111')
      _(record[:abn_status]).must_equal 'ACT'
      _(record[:abn_status_from_date]).must_equal '20261012'
      _(record[:record_last_updated_date]).must_equal '20261013'
      _(record[:replaced]).must_equal 'N'
    end

    it "takes the entity type as both code and text" do
      record = fixture_record('55555555555')
      _(record[:entity_type_code]).must_equal 'DTT'
      _(record[:entity_type_text]).must_equal 'Discretionary Trading Trust'
    end

    it "takes the state and postcode of the main business location" do
      record = fixture_record('44444444444')
      _(record[:state]).must_equal 'NSW'
      _(record[:postcode]).must_equal '2000'
    end

    it "takes the ASIC number along with the type it is given under" do
      record = fixture_record('33333333333')
      _(record[:asic_number]).must_equal '123456789'
      _(record[:asic_number_type]).must_equal 'ACN'
    end

    it "takes a cancelled ABN as readily as a live one" do
      _(fixture_record('66666666666')[:abn_status]).must_equal 'CAN'
    end
  end

  # Every record the extract holds carries a GST element, those not registered among them, so its status says which of the three a record is rather than whether the element was there.
  describe "GST" do
    it "takes an active registration with the date it began" do
      record = fixture_record('33333333333')
      _(record[:gst_status]).must_equal 'ACT'
      _(record[:gst_status_from_date]).must_equal '20261015'
    end

    it "takes a cancelled registration" do
      _(fixture_record('66666666666')[:gst_status]).must_equal 'CAN'
    end

    it "takes no registration as the status it is given, NON" do
      record = fixture_record('99999999999')
      _(record[:gst_status]).must_equal 'NON'
      _(record[:gst_status_from_date]).must_equal '19000101'
    end

    # The schema allows the element to be left off, which is not the same as a status of NON, so the two are not run together.
    it "leaves the status unset where the element is absent" do
      _(fixture_record('11111111111')[:gst_status]).must_be_nil
    end
  end

  describe "the names it collects" do
    it "takes a company's own name as a name of type MN" do
      _(fixture_record('33333333333')[:names]).must_equal [{type: 'MN', text: 'SMITH PLUMBING PTY LTD'}]
    end

    # Joining the parts is a decision for whoever asks, so they are kept as they come.
    it "takes an individual's name in its parts" do
      _(fixture_record('22222222222')[:names].first).must_equal(
        {type: 'LGL', title: 'MS', given_names: ['ANNE', 'MARIE'], family_name: 'NGUYEN'}
      )
    end

    it "takes a family name standing on its own" do
      _(fixture_record('99999999999')[:names]).must_equal [{type: 'LGL', family_name: 'TEOFILO'}]
    end

    it "takes business, trading and other names alongside the entity's own" do
      types = fixture_record('88888888888')[:names].collect{|name| name[:type]}
      _(types).must_equal ['MN', 'BN', 'TRD', 'OTN']
    end

    # The extract is full of ampersands, and a name carrying one encoded is worth nothing if it is read back encoded.
    it "gives back a name with its entities decoded" do
      _(fixture_record('88888888888')[:names].first[:text]).must_equal 'GEELONG COMMUNITY WORKS & TRAINING LIMITED'
    end

    it "keeps an apostrophe as it stands" do
      trading = fixture_record('88888888888')[:names].detect{|name| name[:type] == 'TRD'}
      _(trading[:text]).must_equal "GCW's Training"
    end
  end

  # An entity's own endorsement and each named fund it runs come as DGR elements of the same name, the first carrying a status and no name and the second a name and no status. Running them together would lose which is which.
  describe "deductible gift recipient entries" do
    it "keeps the entity's own endorsement and each named fund apart" do
      _(fixture_record('88888888888')[:dgr]).must_equal [
        {from_date: '20190101', status: 'ACT', name: nil},
        {from_date: '20200401', status: nil, name: 'GEELONG COMMUNITY WORKS PUBLIC FUND'},
      ]
    end

    it "gives no entries where there are none" do
      _(fixture_record('11111111111')[:dgr]).must_equal []
    end
  end

  # An element present and empty is not an element absent, and the extract has both: a blank state against no ASIC number at all.
  describe "what is there and empty against what is not there" do
    it "keeps a blank state and postcode as the blanks they are" do
      record = fixture_record('99999999999')
      _(record[:state]).must_equal ''
      _(record[:postcode]).must_equal ''
    end

    it "leaves what the record does not carry unset" do
      record = fixture_record('11111111111')
      _(record[:asic_number]).must_be_nil
      _(record[:asic_number_type]).must_be_nil
    end
  end

  describe "the shape it yields" do
    # The storage stage writes a row per record, so every record carrying the same keys matters more than the keys being few.
    it "gives every record the same keys" do
      _(fixture_records.collect(&:keys).uniq.length).must_equal 1
    end

    it "gives back an enumerator where no block is given" do
      File.open(fixture_path('20261020Public01.xml'), 'rb') do |file|
        _(DataGovAu::AbnBulkExtract::Parser.new(file).each_record).must_be_kind_of Enumerator
      end
    end
  end
end
