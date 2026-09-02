# Emails from The Afida Stack game. Everything here is transactional — the
# player asked for the code, earned the kickback, or joined the board knowing
# dethronement news travels by email. Marketing consent lives on GameLead and
# is never assumed by these.
class GameMailer < ApplicationMailer
  def win_code(email, code)
    @code = code
    mail to: email, subject: "Your Afida Stack code: #{code}"
  end

  def mate_code(email, code)
    @code = code
    mail to: email, subject: "A mate ordered — your £10 off is in"
  end

  def dethroned(entry, by:)
    @entry = entry
    @by = by
    mail to: entry.email, subject: "You've been dethroned on The Afida Stack"
  end
end
