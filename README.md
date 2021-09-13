![pic](https://static01.imgkr.com/temp/5c72d4df14844960a449af6b73abc36f.png)

一个用swift写的Mac平台的打包软件

**ps:不支持手动签名项目（因为我没弄过）😁**

感谢[aaaaa893215155](https://github.com/aaaaa893215155)的[文章](https://juejin.cn/post/6970958512557916190#heading-10)

感谢[QiuZhiFei](https://github.com/QiuZhiFei)的开源项目[
swift-commands](https://github.com/QiuZhiFei/swift-commands)

可能出现的错误：

在多scheme项目里，可能你输入了项目的scheme，但是出现了如下报错

![2](https://static01.imgkr.com/temp/2fa2e8f5f258477497e1e4f0487d72ee.png)

这是因为你在build setting里的product Name里修改了项目名称，你只需要将其改为scheme重新打包即可