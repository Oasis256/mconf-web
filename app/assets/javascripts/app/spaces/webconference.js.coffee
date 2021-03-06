#= require "../custom_bigbluebutton_rooms/invitation"
#= require "../custom_bigbluebutton_rooms/user_edit"

mconf.Spaces or= {}

class mconf.Spaces.Webconference

  @bind: ->
    @unbind()

    mconf.Resources.addToBind ->
      mconf.CustomBigbluebuttonRooms.Invitation.bind()
      mconf.UserEdit.setup()

    $("#webconference-share .open-modal").on "modal-hidden.mconfSpacesWebconference", ->
      mconf.CustomBigbluebuttonRooms.Invitation.unbind()

  @unbind: ->
    $(document).off "modal-shown.mconfSpacesWebconference"
    $("#webconference-share .open-modal").off "modal-hidden.mconfSpacesWebconference"
