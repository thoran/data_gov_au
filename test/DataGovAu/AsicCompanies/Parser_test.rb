# test/DataGovAu/AsicCompanies/Parser_test.rb

require_relative './helper'

describe DataGovAu::AsicCompanies::Parser do
  def records_of(text)
    DataGovAu::AsicCompanies::Parser.new(StringIO.new(text)).each_record.to_a
  end

  describe "a row" do
    it "comes keyed by the register's columns" do
      _(records_of(asic_register_text).first).must_equal({
        company_name: 'LOVINI HOLDINGS PTY LTD', acn: '000000019',
        type: 'APTY', class: 'LMSH', sub_class: 'PROP', status: 'REGD',
        date_of_registration: '08/01/1990', date_of_deregistration: '',
        previous_state_of_registration: 'NSW', state_registration_number: '46869041',
        modified_since_last_report: '', current_name_indicator: '',
        abn: '89000000019', current_name: 'MONAKA PTY LTD', current_name_start_date: '28/01/2016',
      })
    end

    it "is one name, so that a company comes as many rows as it has held names" do
      _(records_of(asic_register_text).select{|record| record[:acn] == '000000019'}.collect{|record| record[:company_name]}).must_equal ['LOVINI HOLDINGS PTY LTD', 'MONAKA PTY LTD']
    end

    # The register quotes nothing, so a quote is part of the name.
    it "keeps a quote in a name as part of it" do
      _(records_of(asic_register_text).last[:company_name]).must_equal 'TUMUT BOWLING & RECREATION CLUB LTD. TRADING AS "CLUB TUMUT" LTD'
    end

    it "keeps a quote opening a name as part of it" do
      row = ['"KARAISKAKIS" LIMITED', '000842160', 'APUB', 'LMGT', 'ULSN', 'REGD', '02/11/1970', '', 'NSW', '1', '', 'Y', '0', '', '']
      _(records_of(asic_register_text([row])).first[:company_name]).must_equal '"KARAISKAKIS" LIMITED'
    end

    it "gives fields as the strings the register holds, an ABN of 0 and empty fields included" do
      record = records_of(asic_register_text)[2]
      _(record[:abn]).must_equal '0'
      _(record[:current_name]).must_equal ''
      _(record[:date_of_deregistration]).must_equal '13/03/2026'
    end

    it "keeps spaces trailing a name" do
      row = ['THE HOLY APOSTLES LIMITED   ', '001233790', 'APUB', 'LMGT', 'ULSN', 'REGD', '01/01/1977', '', 'NSW', '1', '', 'Y', '0', '', '']
      _(records_of(asic_register_text([row])).first[:company_name]).must_equal 'THE HOLY APOSTLES LIMITED   '
    end

    it "is read as UTF-8 from a stream handing over bytes" do
      text = asic_register_text([['CAFÉ PTY LTD', '000000001', 'APTY', 'LMSH', 'PROP', 'REGD', '01/01/2000', '', '', '', '', 'Y', '0', '', '']]).b
      record = records_of(text).first
      _(record[:company_name]).must_equal 'CAFÉ PTY LTD'
      _(record[:company_name].encoding).must_equal Encoding::UTF_8
    end
  end

  it "counts the rows yielded" do
    parser = DataGovAu::AsicCompanies::Parser.new(StringIO.new(asic_register_text))
    _(parser.each_record{}.records_parsed).must_equal 4
  end

  it "yields nothing from a register holding only its header" do
    _(records_of(asic_register_text([]))).must_equal []
  end

  describe "a register not laid out as ASIC writes it" do
    it "stops where the header names other columns" do
      header = DataGovAu::AsicCompanies::Parser::COLUMNS.keys.rotate
      _(->{records_of(asic_register_text(header: header))}).must_raise DataGovAu::AsicCompanies::RegisterMalformed
    end

    it "stops where there is no header" do
      _(->{records_of('')}).must_raise DataGovAu::AsicCompanies::RegisterMalformed
    end

    it "stops at a row with other than fifteen fields, naming its line" do
      rows = asic_rows.dup.insert(1, asic_rows[1].first(14))
      error = _(->{records_of(asic_register_text(rows))}).must_raise DataGovAu::AsicCompanies::RegisterMalformed
      _(error.message).must_match(/line 3 has 14 fields/)
    end
  end
end
