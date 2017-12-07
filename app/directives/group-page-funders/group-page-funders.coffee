null

### @ngInject ###
global.cobudgetApp.directive 'groupPageFunders', () ->
    restrict: 'E'
    template: require('./group-page-funders.html')
    replace: true
    controller: (config, Dialog, DownloadCSV, LoadBar, $q, Records, $scope, Toast, $window) ->

      Records.memberships.fetchByGroupId($scope.group.id).then ->
        $scope.fundersLoaded = true

      $scope.toggleMemberAdmin = (membership) ->
        membership.isAdmin = !membership.isAdmin
        params =
          membership:
            is_admin: membership.isAdmin
        membership.remote.update(membership.id, params)

      $scope.downloadCSV = ->
        timestamp = moment().format('YYYY-MM-DD-HH-mm-ss')
        filename = "#{$scope.group.name}-member-data-#{timestamp}"
        params =
          url: "#{config.apiPrefix}/memberships.csv?group_id=#{$scope.group.id}"
          filename: filename
        DownloadCSV(params)

      $scope.openResendInvitesDialog = ->
        Dialog.confirm({
          content: "Resend invitations to #{$scope.group.pendingMemberships().length} people?"
        }).then ->
          $scope.resendInvites()

      $scope.resendInvites = ->
        invitesSent = 0
        LoadBar.start({msg: "Resending invites (0 / #{$scope.group.pendingMemberships().length})"})
        promises = []
        _.each $scope.group.pendingMemberships(), (membership) ->
          promise = Records.memberships.invite(membership)
          promise.finally ->
            invitesSent = invitesSent + 1
            LoadBar.updateMsg("Resending invites (#{invitesSent} / #{$scope.group.pendingMemberships().length})")
          promises.push(promise)

        $q.allSettled(promises).finally ->
          Toast.show("#{promises.length} invitations sent!")
          LoadBar.stop()

      # TODO: refactor
      $scope.inviteAgain = (membership) ->
        Dialog.custom
          template: require('./reinvite-user-dialog.tmpl.html')
          scope: $scope
          controller: (Dialog, $mdDialog, Records, $scope, Toast) ->
            $scope.member = membership.member()
            $scope.cancel = ->
              $mdDialog.cancel()
            $scope.proceed = ->
              Records.memberships.invite(membership)
                .then ->
                  $scope.cancel()
                  Toast.show('Invitation sent!')
                .catch ->
                  Dialog.alert({title: 'Error!'})

      $scope.removeMembership = (membership) ->
        removeMembershipDialog = require('./../../components/remove-membership-dialog/remove-membership-dialog.coffee')({
          scope: $scope,
          membership: membership
        })
        Dialog.open(removeMembershipDialog)


      # TODO: refactor
      $scope.openManageFundsDialog = (funderMembership) ->
        Dialog.custom
          scope: $scope
          template: require('./../../directives/group-page-funders/manage-funds-dialog.tmpl.html')
          controller: ($mdDialog, $scope, Records) ->
            $scope.formData = {}
            $scope.mode = 'add'

            if funderMembership.groupAccountBalance
              $scope.managedMembership = funderMembership
              $scope.managedMembership.rawBalance = $scope.managedMembership.groupAccountBalance
              $scope.managedMember = {}
              $scope.managedMember.id = null
              $scope.managedMember.name = 'Group Account'
            else
              $scope.managedMembership = funderMembership
              $scope.managedMember = funderMembership.member()

            $scope.setMode = (mode) ->
              $scope.mode = mode

            $scope.normalizeAllocationAmount = ->
              allocationAmount = $scope.formData.allocationAmount || 0
              if allocationAmount + $scope.managedMembership.rawBalance < 0
                $scope.formData.allocationAmount = -$scope.managedMembership.rawBalance

            $scope.normalizeNewBalance = ->
              if $scope.formData.newBalance < 0
                $scope.formData.newBalance = 0

            $scope.isValidForm = ->
              ($scope.mode == 'add' && $scope.formData.allocationAmount) || ($scope.mode == 'change' && ( $scope.formData.newBalance || $scope.formData.newBalance == 0))

            $scope.cancel = ->
              $mdDialog.cancel()

            $scope.createAllocation = ->
              if $scope.mode == 'add'
                amount = $scope.formData.allocationAmount
              if $scope.mode == 'change'
                amount = $scope.formData.newBalance - $scope.managedMembership.rawBalance
              params = {groupId: $scope.group.id, userId: $scope.managedMember.id, amount: amount }
              allocation = Records.allocations.build(params)
              allocation.save()
                .then (res) ->
                  Records.memberships.findOrFetchById($scope.managedMembership.id)
                  Dialog.alert(title: 'Success!')
                .catch (err) ->
                  Dialog.alert(title: 'Error!')
                .finally ->
                  $scope.cancel()

      return
