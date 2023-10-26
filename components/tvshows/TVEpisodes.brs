import "pkg:/source/api/Image.brs"
import "pkg:/source/api/baserequest.brs"
import "pkg:/source/utils/config.brs"
import "pkg:/source/utils/misc.brs"
import "pkg:/source/api/sdk.bs"

sub init()
    m.top.optionsAvailable = false

    m.rows = m.top.findNode("picker")
    m.poster = m.top.findNode("seasonPoster")
    m.Shuffle = m.top.findNode("Shuffle")
    m.tvEpisodeRow = m.top.findNode("tvEpisodeRow")

    m.unplayedCount = m.top.findNode("unplayedCount")
    m.unplayedEpisodeCount = m.top.findNode("unplayedEpisodeCount")

    m.rows.observeField("doneLoading", "updateSeason")

    m.di = CreateObject("roDeviceInfo")
end sub

sub setSeasonLoading()
    m.top.overhangTitle = tr("Loading...")
end sub

sub updateSeason()
    if m.global.session.user.settings["ui.tvshows.disableUnwatchedEpisodeCount"] = false
        if isValid(m.top.seasonData) and isValid(m.top.seasonData.UserData) and isValid(m.top.seasonData.UserData.UnplayedItemCount)
            if m.top.seasonData.UserData.UnplayedItemCount > 0
                m.unplayedCount.visible = true
                m.unplayedEpisodeCount.text = m.top.seasonData.UserData.UnplayedItemCount
            end if
        end if
    end if

    imgParams = { "maxHeight": 450, "maxWidth": 300 }
    m.poster.uri = ImageURL(m.top.seasonData.Id, "Primary", imgParams)
    m.Shuffle.visible = true
    m.top.overhangTitle = m.top.seasonData.SeriesName + " - " + m.top.seasonData.name
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    handled = false

    if key = "left" and m.tvEpisodeRow.hasFocus()
        m.Shuffle.setFocus(true)
        return true
    end if

    if key = "right" and (m.Shuffle.hasFocus())
        m.tvEpisodeRow.setFocus(true)
        return true
    end if

    if (key = "OK" and press = false) or key = "play"

        if m.Shuffle.hasFocus()
            episodeList = m.rows.getChild(0).objects.items

            for i = 0 to episodeList.count() - 1
                j = Rnd(episodeList.count() - 1)
                temp = episodeList[i]
                episodeList[i] = episodeList[j]
                episodeList[j] = temp
            end for

            m.global.queueManager.callFunc("set", episodeList)
            m.global.queueManager.callFunc("playQueue")
            return true
        end if
    end if

    focusedChild = m.top.focusedChild.focusedChild
    if focusedChild.content = invalid then return handled

    ' OK needs to be handled on release...
    proceed = false
    if key = "OK" and press = false
        if m.di.TimeSinceLastKeypress() > 2
            ' If OK was pressed for more than the threshold time then handle this as a long pressed operation
            itemToPlay = focusedChild.content.getChild(focusedChild.rowItemFocused[0]).getChild(0)

            ' Modify text to show in options menu based on if episde is currently marked as watched or not
            ' Only show opposite option to what item is currently marked as
            watchedOptionText = "Mark "
            if itemToPlay.content.watched
                watchedOptionText += "Watched"
            else
                watchedOptionText += " Unwatched"
            end if

            selectedOption = option_dialog([watchedOptionText, "Cancel"], "Additional Options")

            if LCase(selectedOption) <> LCase("cancel")
                if isValid(itemToPlay) and isValid(itemToPlay.id) and itemToPlay.id <> ""
                    ' Marked as watched or unwatched based on what property was showing in the options dialog
                    isWatched = itemToPlay.content.watched
                    if LCase(selectedOption) = LCase("Mark Watched")
                        api.users.MarkPlayed(m.global.session.user.id, itemToPlay.id)
                        isWatched = true
                    end if

                    if LCase(selectedOption) = LCase("Mark Unwatched")
                        api.users.UnmarkPlayed(m.global.session.user.id, itemToPlay.id)
                        isWatched = false
                    end if

                    ' Refresh view to show that episode was marked as watched
                    itemToPlay.content.watched = isWatched
                    group = m.scene.focusedChild
                    group.timeLastRefresh = CreateObject("roDateTime").AsSeconds()
                    group.callFunc("refresh")
                end if
            end if
        else
            ' If the ok button was released before
            proceed = true
        end if
    end if

    if press and key = "play" or proceed = true
        m.top.lastFocus = focusedChild
        itemToPlay = focusedChild.content.getChild(focusedChild.rowItemFocused[0]).getChild(0)
        if isValid(itemToPlay) and isValid(itemToPlay.id) and itemToPlay.id <> ""
            itemToPlay.type = "Episode"
            m.top.quickPlayNode = itemToPlay
        end if
        handled = true
    end if

    if key = "OK" and press
        m.okPressedDateTime = CreateObject("roDateTime")
        return true
    end if

    return handled
end function
