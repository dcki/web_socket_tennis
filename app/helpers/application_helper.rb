module ApplicationHelper
  def current_user
    User.find_by_session(cookies)
  end

  def class_for_flash(type)
    case type.to_s
    when 'error'
      'flash_error'
    end
  end
end
