require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

include Arby::Dsl

alloy_model "A_D_AME" do
  sig Credential
  sig AuthGrant
  sig AccessToken
  sig Resource

  sig Client, {
    cred: Credential
  } do
    # exports
    def sendResp(data) end

    # invokes
    def __invokes_reqAuth()        ResourceOwner.reqAuth end
    def __invokes_reqRes()         ResourceServer.reqRes end
    def __invokes_reqAccessToken() ResourceServer.reqAccessToken end
  end

  sig ResourceOwner, {
    authGrants: Credential * AuthGrant
  } do
    #exports
    def reqAuth(cred)
      cred < authGrants.keys
    end

    #invokes
    def __after_reqAuth(cred)
      Client.sendResp(authGrants[cred])
    end
  end

  sig AuthorizationServer, {
    accessTokens: AuthGrant * AccessToken
  } do
    #exports
    def reqAccessToken(grant)
      grant < accessTokens.keys
    end

    #invokes
    def __after_reqAccessToken(grant)
      Client.sendResp(accessTokens[grant])
    end
  end

  sig ResourceServer, {
    resources: AccessToken * Resource
  } do
    #exports
    def reqRes(token)
      token < resources.keys
    end

    #invokes
    def __after_reqRes(token)
      Client.sendResp(resources[token])
    end
  end
end


class TestAlloyModelExpr < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers

  def test_dummy
  end


end
