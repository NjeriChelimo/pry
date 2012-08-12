class Pry
  # N.B. using a regular expresion here so that "raise-up 'foo'" does the right thing.
  Pry::Commands.create_command(/raise-up(!?\b.*)/, :listing => 'raise-up') do
    description "Raise an exception out of the current pry instance."
    banner <<-BANNER
      Raise up, like exit, allows you to quit pry. Instead of returning a value however, it raises an exception.
      If you don't provide the exception to be raised, it will use the most recent exception (in pry _ex_).

      e.g. `raise-up "get-me-out-of-here"` is equivalent to:
           `raise "get-me-out-of-here"
            raise-up`

      When called as raise-up! (with an exclamation mark), this command raises the exception through
      any nested prys you have created by "cd"ing into objects.
    BANNER

    def process
      return stagger_output help if captures[0] =~ /(-h|--help)\b/
      # Handle 'raise-up', 'raise-up "foo"', 'raise-up RuntimeError, 'farble' in a rubyesque manner
      target.eval("_pry_.raise_up#{captures[0]}")
    end
  end
end