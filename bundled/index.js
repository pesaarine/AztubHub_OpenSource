"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const path_1 = __importDefault(require("path"));
const fs_1 = __importDefault(require("fs"));
const crypto_1 = require("crypto");
const gameList_json_1 = __importDefault(require("./gameList.json"));
const dotenv_1 = require("dotenv");
(0, dotenv_1.config)();
const router = (0, express_1.default)();
router.use(express_1.default.json());
const API_KEY = process.env.API_KEY;
const requireRegex = /require\(['"]([^'"]+)['"]\)/g;
const sharedRequireRegex = /sharedRequire\(['"]([^'"]+)['"]\)/g;
const getServerConstantRegex = /getServerConstant\(['"]([^'"]+)['"]\)/g;
function getAllRequireForFile(filePath, gameId, gameName, original = true, fileIds = new Map(), allFiles = new Map(), serverConstants = new Map()) {
    const extension = path_1.default.parse(filePath).ext;
    const gameNameSpaceLess = gameName.replace(/\s/g, '');
    const baseAppend = fs_1.default.readFileSync('base-append.lua');
    const isFolder = fs_1.default.existsSync(path_1.default.join(__dirname, 'files', 'games', gameName.replace(/\s/g, '')));
    let fileContent = fs_1.default.readFileSync(filePath).toString();
    // We turn JSON into a lua string that we can then parse later
    if (extension === '.json') {
        fileContent = `return [[${JSON.stringify(JSON.parse(fileContent))}]]`;
    }
    ;
    fileContent = fileContent.replace('GAMES_SETUP();', `if (gameName == '${gameName}') then require('games/${gameNameSpaceLess}${isFolder ? '/main.lua' : '.lua'}') end`);
    fileContent = fileContent.replace(requireRegex, (str, scriptPath) => {
        const realPath = path_1.default.join(path_1.default.join(filePath, '../'), scriptPath);
        let [fileContent] = getAllRequireForFile(realPath, gameId, gameName, false, fileIds, allFiles, serverConstants);
        fileContent = fileContent.split('\n').map(str => '\t' + str).join('\n');
        return `(function()\n${fileContent}\nend)()`;
    });
    fileContent = fileContent.replace(sharedRequireRegex, (str, scriptPath) => {
        let oldFilePath = filePath;
        if (scriptPath.startsWith('@')) {
            oldFilePath = 'files/_.lua';
            scriptPath = scriptPath.substring(1);
        }
        const realPath = path_1.default.join(path_1.default.join(oldFilePath, '../'), scriptPath);
        const [fileContent] = getAllRequireForFile(realPath, gameId, gameName, false, fileIds, allFiles, serverConstants);
        if (!fileIds.has(realPath)) {
            allFiles.set(realPath, fileContent);
            fileIds.set(realPath, (0, crypto_1.createHash)('sha256').update(realPath).digest('hex'));
        }
        return `sharedRequires['${fileIds.get(realPath)}']`; // (function()\n${fileContent}\nend)()`;
    });
    fileContent = fileContent.replace(getServerConstantRegex, (str, constName) => {
        if (!serverConstants.has(constName)) {
            const hash = (0, crypto_1.createHash)('md5').update(gameNameSpaceLess + constName).digest('hex');
            serverConstants.set(constName, hash);
        }
        return `serverConstants['${serverConstants.get(constName)}']`;
    });
    if (original) {
        // If its the original file(source.lua) we append all the sharedRequires['test'] = (function() end)(); and we also append the base-append.lua file
        let sharedRequires = '';
        allFiles.forEach((fileContent, fileId) => {
            fileContent = fileContent.split('\n').map((str) => {
                return '\t' + str;
            }).join('\n');
            sharedRequires += `\nsharedRequires['${fileIds.get(fileId)}'] = (function()\n${fileContent}\nend)();\n`;
        });
        fileContent = baseAppend + sharedRequires + fileContent;
    }
    ;
    return [fileContent, serverConstants];
}
;
router.get('/compile', (req, res) => {
    const version = (0, crypto_1.randomBytes)(8).toString('hex');
    const metadata = { games: {}, version };
    const serverConstants = [];
    if (!fs_1.default.existsSync('bundled'))
        fs_1.default.mkdirSync('bundled');
    if (!fs_1.default.existsSync(`bundled/${version}`))
        fs_1.default.mkdirSync(`bundled/${version}`);
    if (!fs_1.default.existsSync(`bundled/latest`))
        fs_1.default.mkdirSync(`bundled/latest`);
    for (const [gameId, gameName] of Object.entries(gameList_json_1.default)) {
        try {
            let [outFile, smallServerConstants] = getAllRequireForFile(path_1.default.join('files', 'source.lua'), gameId, gameName);
            const constants = {};
            smallServerConstants.forEach((i, v) => constants[i] = v);
            serverConstants.push({ gameId, constants });
            fs_1.default.writeFileSync(`bundled/latest/${gameName.replace(/\s/g, '')}.lua`, outFile);
            fs_1.default.writeFileSync(`bundled/${version}/${gameName.replace(/\s/g, '')}.lua`, outFile);
        }
        catch (error) {
            console.log(error);
            return res.json({
                success: false,
                message: error.message
            });
        }
    }
    // Remove all spaces from game metadata
    Object.entries(gameList_json_1.default).forEach(([i, v]) => metadata.games[i] = v.replace(/\s/g, ''));
    fs_1.default.writeFileSync(`bundled/${version}/metadata.json`, JSON.stringify(metadata));
    fs_1.default.writeFileSync(`bundled/latest/metadata.json`, JSON.stringify(metadata));
    fs_1.default.writeFileSync(`bundled/latest/serverConstants.json`, JSON.stringify(serverConstants));
    return res.json({ success: true });
});
router.get('/gameList', (req, res) => {
    return res.json(gameList_json_1.default);
});
router.use((req, res, next) => {
    const apiKey = req.header('Authorization');
    if (apiKey !== API_KEY)
        return res.sendStatus(401);
    next();
});
router.post('/getFile', (req, res) => {
    const paths = req.body.paths;
    if (paths[0].startsWith('@')) {
        paths[0] = paths[0].substring(1);
        paths[1] = '';
    }
    else {
        paths[1] = path_1.default.join(paths[1], '../');
    }
    let filePath = path_1.default.join('files', paths[1], paths[0]);
    const fileExists = fs_1.default.existsSync(filePath);
    if (!fileExists) {
        const pathInfo = path_1.default.parse(filePath);
        filePath = path_1.default.join(pathInfo.dir, pathInfo.name, '/main.lua');
    }
    res.header('File-Path', filePath.substring(6));
    return res.send(fs_1.default.readFileSync(filePath).toString());
});
router.use(express_1.default.static(path_1.default.join(__dirname, 'files')));
router.use((req, res, next) => {
    return res.status(400).json({
        success: false,
        code: 404,
        message: 'Page not found.'
    });
});
router.listen(4566, () => {
    console.log('app listening on port 4566');
});
