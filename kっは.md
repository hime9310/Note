**前提：2つの環境**
- **DCS Hub**：Deloitte NW（社内網）とつながる閉域寄りの環境です。外部接続は原則不可で、Public IPを持たせるには申請が必要です。
- **DCS Disconnected**：Deloitte NWとはつながらず、Internet上で動く環境です。

**Venafiの役割**
- Venafiで証明書を発行・管理し、更新後の証明書を各CSPへ自動で反映します。
- AWSの場合は、ACMの証明書を更新するとLBにも自動で反映されます。

**AWS：Hub・Discどちらも自動更新できる**
- VenafiはIAM role（STS AssumeRole）で認証し、ACMのAPIを呼び出しています。
- このAPIはAWSのPublic endpointで提供されているので、対象環境がDeloitte NWにつながっているかどうかは関係ありません。
- そのため、HubでもDiscでも同じ仕組みで自動更新できます。

**Azure：Hubはできる、Discはできない**
- AzureはAWSと仕組みが違い、Backbone通信（Private IP）で連携します。
- **Hub**：Private IPで疎通できるので、自動更新できます。
- **Disc**：連携に有効なService Account（おそらくService Principal）が必要です。ところが、Venafiが構築されているGlobal側のService Account情報が分からないため、現状は設定できず、自動更新できません。

**論点（午後のKCM会議向け）**
- Azure Discの自動更新を実現するには、Global側のService Account情報を入手する必要があります。そのための依頼先と手続きをKCMと確認する必要があります。
- 入手が難しい場合は、Azure Discだけ手動更新で運用するか、別の連携方法を検討するかの判断も必要になります。

**Background: Two Environments**
- **DCS Hub**: A closed environment connected to the Deloitte network. External connectivity is not permitted by default, and a request is required to assign a public IP.
- **DCS Disconnected**: An internet-facing environment that is not connected to the Deloitte network.

**Role of Venafi**
- Venafi issues and manages certificates, and automatically deploys renewed certificates to each CSP.
- On AWS, updating a certificate in ACM is automatically reflected on the load balancer.

**AWS: Auto-renewal works in both Hub and Disconnected**
- Venafi authenticates via an IAM role (STS AssumeRole) and calls the ACM APIs.
- These APIs are served through AWS public endpoints, so whether the target environment is connected to the Deloitte network does not matter.
- As a result, auto-renewal works the same way in both environments.

**Azure: Works in Hub, not in Disconnected**
- Unlike AWS, the Azure integration relies on backbone communication over private IPs.
- **Hub**: Private IP connectivity is available, so auto-renewal works.
- **Disconnected**: The integration requires a valid service account (likely a service principal). However, we do not have the service account information from the Global side, where Venafi is hosted. Therefore, it cannot be configured at this time, and auto-renewal is not possible.

**Discussion Points (for this afternoon's meeting with KCM)**
- To enable auto-renewal for Azure Disconnected, we need to obtain the Global-side service account information. We need to confirm with KCM whom to contact and what process to follow.
- If obtaining this information proves difficult, we will need to decide whether to manage Azure Disconnected certificates through manual renewal or to explore an alternative integration method.
