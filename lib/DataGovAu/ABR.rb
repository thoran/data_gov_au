# DataGovAu/ABR.rb
# DataGovAu::ABR

# The bulk extract's module by the name it had before 0.4.0, so that code which reads the extract without a Config, as through the Parser, still loads. Deprecated, and removed in 0.5.0.

require_relative './AbnBulkExtract'

module DataGovAu
  ABR = AbnBulkExtract
  deprecate_constant :ABR
end
