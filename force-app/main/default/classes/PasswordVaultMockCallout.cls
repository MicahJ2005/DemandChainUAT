@isTest
global class PasswordVaultMockCallout implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        String endpoint = req.getEndpoint();
        String method = req.getMethod();
        String resBody = '';
        Integer statusCode;

        if (endpoint.endsWith('vaults/123') && method == 'GET') {
            // get vault info
            resBody = '{"id": "123", "name": "Daily Bugle", "content_version": 1, "attribute_version": 1, "items": 0, "type": "USER_CREATED", "created_at": "2023-11-25T21:24:08Z", "updated_at": "2023-11-25T21:24:08Z"}';
            statusCode = 200;
        } else if (endpoint.endsWith('vaults')) {
            if (method == 'POST') {
                // create vault
                resBody = '{"id":"123","name":"Daily Bugle","content_version":1,"attribute_version":1,"items":0,"type":"USER_CREATED","created_at":"2023-11-25T21:24:08Z","updated_at":"2023-11-25T21:24:08Z"}';
                statusCode = 200;
            } else if (method == 'DELETE') {
                // delete vault
                resBody = '';
                statusCode = 200;
            }
        } else if (endpoint.endsWith('vaults/123/users') && method == 'POST') {
            // add user to vault
            resBody = '{"vault_id":"123","vault_name":"Daily Bugle","user_id":"456","user_email":"gwenstacy@example.com","permissions":"view_items,create_items,edit_items,archive_items,delete_items,view_and_copy_passwords,view_item_history,import_items,export_items,copy_and_share_items,print_items"}';
            statusCode = 200;
        } else if (endpoint.endsWith('vaults/123/users') && method == 'DELETE') {
            // remove user from vault
            resBody = '{"vault_id":"123","vault_name":"Daily Bugle","user_id":"456","user_email":"gwenstacy@example.com","permissions":""}';
            statusCode = 200;
        } else if (endpoint.endsWith('vaults/123/users') && method == 'GET') {
            // get users in vault
            resBody = '[{"id":"456","name":"Gwen Stacy","email":"gwenstacy@example.com"}, {"id":"789","name":"Peter Parker","email":"peterparker@example.com"]';
            statusCode = 200;
        } else if (endpoint.endsWith('users/gwenstacy@example.com') && method == 'GET') {
            // get user info
            resBody = '{"id":"456","name":"Gwen Stacy","email":"gwenstacy@example.com"}';
            statusCode = 200;
        } else {
            System.assert(false, 'unexpected endpoint ' + endpoint);
            return null;
        }

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(resBody);
        res.setStatusCode(statusCode);

        return res;
    }
}