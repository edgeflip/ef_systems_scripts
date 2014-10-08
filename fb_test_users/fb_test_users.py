#!/bin/python
import sys
import urllib2
import json
import argparse
from urllib import urlencode
import httplib




FB_APP_ID = '471727162864364'
FB_APP_SECRET = '120fe5e6d5bffa6a9aa3bf075bd3076a'
DEFAULT_PASSWORD = 'edgeflip'




def int2str(number):
    words = ['Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine']
    return "".join([ words[int(digit)] for digit in str(number) ])

def get_app_token(app_id, app_secret):              
    # https://graph.facebook.com/oauth/access_token?client_id=111399285589490&client_secret=ca819150ad771e5cbcacf60bd88c04d7&grant_type=client_credentials
    url = "https://graph.facebook.com/oauth/access_token?client_id=" + app_id
    url += "&client_secret=" + app_secret + "&grant_type=client_credentials"
    line = urllib2.urlopen(url).readline() 
    # should have: 'access_token=471727162864364|jVJvD2JfB6iwFvx9evMLOgLQiNg'
    tag = 'access_token='
    pos = line.index(tag) + len(tag)
    tok = line[pos:]
    return tok

def get_user_token(fbid, app_id, app_token):
    for user in get_test_users(app_id, app_token):
        if user['id'] == fbid:
            return user['access_token']
    else:
         return False
    
def get_test_users(app_id, app_token):
    # https://graph.facebook.com/111399285589490/accounts/test-users?access_token=111399285589490|ChvF9GrYd2K9cHq07NQmcSVhDsc
    url = "https://graph.facebook.com/" + app_id + "/accounts/test-users?access_token=" + app_token
    users_json = json.load(urllib2.urlopen(url))['data']  
    # each entry should have: id, access_token, login_url
    return users_json 

def info_from_fbid(fbid):
    url = "https://graph.facebook.com/" + fbid
    # {
    #    "id": "100003222687678",
    #    "first_name": "Matthew",
    #    "gender": "male",
    #    "last_name": "Rattigan",
    #    "locale": "en_US",
    #    "name": "Matthew Rattigan",
    #    "username": "mattratt1884"
    # }
    return json.load(urllib2.urlopen(url))

def infos_from_fbids(fbids, app_token):
    queries = []
    for fbid in fbids:
        queries.append({'method':'GET', 'relative_url':fbid})
    url = "https://graph.facebook.com/"
    encodes = urlencode([
        ('batch', json.dumps(queries)),
        ('access_token', app_token),
    ])
    responses = json.load(urllib2.urlopen(url, encodes))
    # print "got responses: " + str(responses)
    return [resp['body'] for resp in responses]
        
def create_test_user(name, app_id, app_token):
    # https://graph.facebook.com/APP_ID/accounts/test-users?
    #   installed=true
    #   &name=FULL_NAME
    #   &locale=en_US
    #   &permissions=read_stream
    #   &method=post
    #   &access_token=APP_ACCESS_TOKEN
    url = 'https://graph.facebook.com/' + app_id + '/accounts/test-users'
    encodes = urlencode([
        ('installed', 'true'),
        ('permissions', 'read_stream,user_photos,friends_photos,email,user_birthday,' +
            'friends_birthday,user_about_me,user_location,friends_location,user_likes,' +
            'friends_likes,user_interests,friends_interests'),
        ('name', name),
        # ('locale', 'en_US'),
        ('access_token', app_token),
    ])
    print "posting: " + url + " " + encodes
    try:
        response = json.load(urllib2.urlopen(url, encodes))
    except urllib2.HTTPError as err:
        print "error: %d '%s' %s" % (err.code, err.reason, str(err))
        raise 
    print "got: " + str(response)
    # should have: id, access_token, login_url, email, password
    return response


def create_test_user_httplib(name, app_id, app_token):
    conn = httplib.HTTPSConnection('graph.facebook.com')
    url = "/%s/accounts/test-users?access_token=%s&installed=true&name=%s" % (app_id, app_token, name)
    conn.request('POST', url)
    resp = conn.getresponse()
    content = resp.read()
    print "create got: " + content
    return (content == 'true')


# N.B.: calling this for password will invalidate preexisting access token
def update_user(fbid, user_token, name=None, passwd=None):
    url = 'https://graph.facebook.com/' + fbid
    unencodes = [ ('access_token', user_token) ]
    if (name is not None):
        unencodes.append(('name', name))
    if (passwd is not None):
        unencodes.append(('password', passwd))    
    return json.load(urllib2.urlopen(url, urlencode(unencodes)))
    
def delete_user(fbid, app_id, app_token):
    conn = httplib.HTTPSConnection('graph.facebook.com')
    conn.request('DELETE', "/%s?access_token=%s" % (fbid, app_token))
    resp = conn.getresponse()
    content = resp.read()
    print "delete got: " + content
    return (content == 'true')

def make_friends(infos, app_token):
    link_count = 0
    fail_count = 0
    for i in range(len(infos)):
        info1 = infos[i]
        for info2 in infos[i+1:]:            
            url = 'https://graph.facebook.com/' + info1['id'] + '/friends/' + info2['id'] 
            encodes = urlencode([('access_token', info1['access_token'])])
            response = json.load(urllib2.urlopen(url, encodes))
            if response:
                url = 'https://graph.facebook.com/' + info2['id'] + '/friends/' + info1['id']
                encodes = urlencode([('access_token', info2['access_token'])])
                response = json.load(urllib2.urlopen(url, encodes))
                if response:
                    link_count += 1
                else:
                    fail_count += 1
            else:
                fail_count += 1
    return link_count









############################################

if __name__ == "__main__":

    app_id = FB_APP_ID
    app_token = get_app_token(app_id, FB_APP_SECRET)              

    parser = argparse.ArgumentParser()
    parser.add_argument('op', choices=['list', 'html', 'create', 'token', 'rename'])
    parser.add_argument('opargs', nargs='*')
    args = parser.parse_args()

    if args.op == 'list':
        # each entry should have: id, access_token, login_url
        users = get_test_users(app_id, app_token)
        infos = infos_from_fbids([user['id'] for user in users], app_token)
        for info in infos:
            print str(info) + "\n"
        
    elif args.op == 'create':
        num, lname = args.opargs
        infos = []
        for i in range(int(num)):
            fname = int2str(i)
            name = fname + " " + lname
            # for some new reason, this is returning a 500
            info = create_test_user(name, app_id, app_token)
            # try with httplib instead
            # stuff = create_test_user_httplib(name, app_id, app_token)

        
    elif args.op == 'token':
        print app_token
        
    elif args.op == 'rename':
        fbid, name = args.opargs
        user_token = get_user_token(fbid, app_id, app_token)
        update_user(fbid, user_token, name)
        
        
            

    # elif args.op == 'html':
            
        
    # return users_json
        

    
    # parser.add_argument('--list')
    #
    # if args.list:
    #     for user in get_test_users():
    #         print user





    #
    #
    #
    #
    # num = int(sys.argv[1])
    # lname = sys.argv[2]
    #
    # infos = []
    # for i in range(num):
    #     fname = int2str(i)
    #     name = fname + " " + lname
    #     info = create_test_user(name, app_id, app_token)
    #
    #     # should have: id, access_token, login_url, email, password
    #     print name + "\t" + info['login_url'] + "\n"
    #     infos.append(info)
    #
    # # make 'em all friends
    # link_count = make_friends(infos, app_token)
    # print "made %d relationships" % link_count

    # # get_app_token()
    # users = get_test_users()
    # print "\ngot %d test users" % len(users)
    #
    # create_test_user("Trevo Noisulli")
    #
    # users = get_test_users()
    # print "\nnow got %d test users" % len(users)
    #
    # delete_user(sys.argv[1])
    # print "\nnow now got %d test users" % len(users)


    





